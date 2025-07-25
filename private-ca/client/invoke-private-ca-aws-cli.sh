#!/bin/bash

CA_ACTION=${1}
ENVIRONMENT=${2:-"client"}
AWS_EC2_REGION=${3:-"eu-central-1"}
USER_SSH_DIR=${4:-"$HOME/.ssh"}
USER_AWS_DIR=${5:-"$HOME/.aws"}
SYSTEM_SSH_DIR=${6:-"/etc/ssh"}
CA_LAMBDA_FUNCTION_NAME=${7:-"privateCA"}
LAMBDA_REGION=${8:-'eu-central-1'}
AWS_STS_REGION=${9:-"eu-central-1"}

CERT_HALF_LIFE_SECONDS=${10:-$((3 * 24 * 60 * 60))}

PYTHON_EXEC=$(which python 2>/dev/null || which python3 2>/dev/null)
[[ $? -ne 0 ]] && { echo "Python binary not found."; exit 1; }

trap 'clean_config_on_error' EXIT

clean_config_on_error() {
    rm -f private-ca-client-response.json private-ca-client-event.json
    if [[ $? -ne 0 && $CA_ACTION == "generateHostSSHCert" ]]; then
        if [[ "$CERT_VALID" == "true" ]]; then
            echo "Keeping existing valid certificate."
        else 
            echo "Certificate generation failed and current cert would expire before next run. Cleaning host SSH config..."
            sed -i "\|^HostCertificate ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub\$|d"  ${SYSTEM_SSH_DIR}/sshd_config
            sed -i "\|^TrustedUserCAKeys ${SYSTEM_SSH_DIR}/user_ca.pub\$|d"  ${SYSTEM_SSH_DIR}/sshd_config

            systemctl restart sshd
            echo "Host SSH config cleaned."
        fi
    fi
}

get_aws_credentials() {
    local TEMP_CREDS

    if [[ $ENVIRONMENT == "host" ]]; then
        TOKEN=$(curl -s --max-time 30 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 120")

        if [[ -z "$TOKEN" ]]; then
            echo "Failed to fetch EC2 metadata token. Are you running this script on an EC2 instance?"
            exit 1
        fi

        INSTANCE_ROLE_NAME=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/)
        TEMP_CREDS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/$INSTANCE_ROLE_NAME)
        
    elif [[ $ENVIRONMENT == "client" ]]; then
        if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" && -n "$AWS_SESSION_TOKEN" ]]; then
            CALLER_IDENTITY=$(aws sts get-caller-identity)
            [[ $? -ne 0 ]] && { echo "Your AWS credentials have either expired or are invalid. Please check your credentials and try again."; exit 1; }
            TEMP_CREDS=$(echo "{\"AccessKeyId\":\"$AWS_ACCESS_KEY_ID\",\"SecretAccessKey\":\"$AWS_SECRET_ACCESS_KEY\",\"Token\":\"$AWS_SESSION_TOKEN\"}")
        else
            TEMP_CREDS=$(aws configure export-credentials 2>/dev/null)
            SESSION_TOKEN=$(echo "$TEMP_CREDS" | jq -r '.Token // .SessionToken // .Sessiontoken // empty')
            [[ -z "$SESSION_TOKEN" ]] && TEMP_CREDS=$(aws sts get-session-token | jq -r ".Credentials")
        fi
    else 
        echo "Invalid environment provided. Allowed values are 'host' and 'client'"; exit 1;
    fi

    ACCESS_KEY_ID=$(echo $TEMP_CREDS | jq -r ".AccessKeyId")
    SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | jq -r ".SecretAccessKey")
    SESSION_TOKEN=$(echo $TEMP_CREDS | jq -r ".Token // .SessionToken // .Sessiontoken")
}

prepare_event_json() {
    # Setup Python virtual environment
    if [ ! -d "private-ca-client-env" ]; then
        $PYTHON_EXEC -m venv private-ca-client-env
    fi
    source ./private-ca-client-env/bin/activate
    pip install -q --upgrade --disable-pip-version-check boto3

    # Update PYTHON_EXEC to use the Python executable from the activated virtual environment
    # This ensures we use the venv's Python with the installed dependencies (boto3)
    PYTHON_EXEC=$(which python 2>/dev/null || which python3 2>/dev/null)

    # Generate Auth Headers
    output=$($PYTHON_EXEC aws-auth-header.py $ACCESS_KEY_ID $SECRET_ACCESS_KEY $SESSION_TOKEN $AWS_STS_REGION) || {
        echo "Failed to generate auth header. Check aws-auth-header.py script.";
        exit 1;
    }
    auth_header=$(echo "$output" | jq -er ".Authorization") || {
        echo "Failed to parse Authorization from auth-header output.";
        exit 1;
    }
    date=$(echo "$output" | jq -er ".Date") || {
        echo "Failed to parse Date from auth-header output.";
        exit 1;
    }

    INNER_JSON=$(jq -n \
    --arg amzDate "$date" \
    --arg authHeader "$auth_header" \
    --arg sessionToken "$SESSION_TOKEN" \
    --arg certPubkey "$CERT_PUBKEY" \
    --arg action "$CA_ACTION" \
    --arg awsRegion "$AWS_STS_REGION" \
    --arg awsEC2Region "$AWS_EC2_REGION" \
    '{
        auth: {
            amzDate: $amzDate,
            authorizationHeader: $authHeader,
            sessionToken: $sessionToken
        },
        certPubkey: $certPubkey,
        action: $action,
        awsSTSRegion: $awsRegion,
        awsEC2Region: $awsEC2Region
    }' | jq -c)

    # JSON with body as stringified JSON as required by server
    json_body=$(jq -n --arg body "$INNER_JSON" '{body: $body}')
    echo "$json_body" > private-ca-client-event.json
}

invoke_lambda() {
    INVOKE_OUTPUT=$(aws lambda invoke \
        --function-name ${CA_LAMBDA_FUNCTION_NAME} \
        --cli-binary-format raw-in-base64-out \
        --payload file://private-ca-client-event.json \
        private-ca-client-response.json \
        --region $LAMBDA_REGION) || {
        echo "$INVOKE_OUTPUT"
        echo "Lambda invocation failed"
        exit 1
    }

    response_body=$(cat private-ca-client-response.json | jq -r ".body") || {
        echo "Failed to parse response body.";
        exit 1
    }
    status_code=$(cat private-ca-client-response.json | jq -r ".statusCode") || {
        echo "Failed to parse status code.";
        exit 1
    }

    if [[ $status_code -ne 200 ]]; then
        echo "CA request failed (Status: ${status_code}): ${response_body}"
        exit 1
    fi

     # If the action is getHostCAPublicKey, we don't get a certificate
    [[ $CA_ACTION == "getHostCAPublicKey" ]] && return

    ENCODED_CERTIFICATE=$(echo "$response_body" | jq -er ".certificate") || {
        echo "Certificate not found in Lambda response. Aborting.";
        exit 1;
    }
    
    CERTIFICATE=$(echo $ENCODED_CERTIFICATE | base64 -d) 

    if [[ -z "$CERTIFICATE" ]]; then
        echo "Invalid certificate received. Aborting."
        exit 1
    fi
}

safe_replace_old_certificate() {
    local CERTIFICATE=${1}
    local CERT_FILE_PATH=${2}

    local TEMP_CERT_FILE="${CERT_FILE_PATH}.tmp"

    echo "$CERTIFICATE" > "$TEMP_CERT_FILE"
    
    # Verify the new certificate is valid
    if ssh-keygen -Lf "$TEMP_CERT_FILE" >/dev/null 2>&1; then
        mv "$TEMP_CERT_FILE" "${CERT_FILE_PATH}"
        echo "New certificate written to ${CERT_FILE_PATH}"
        CERT_VALID=true
    else
        rm -f "$TEMP_CERT_FILE"
        echo "Generated certificate is invalid. Discarding."
        exit 1
    fi
}

# Check for options
while getopts ":h" option; do
   case $option in
      h)
         echo "Usage: bash generate-certificate-aws-cli.sh [ACTION] [ENVIRONMENT] [AWS PROFILE] [USER SSH DIR] [USER AWS DIR] [SYSTEM SSH DIR] [AWS STS REGION]"
         echo ""
         echo "Actions:"
         echo "  generateHostSSHCert     Generates SSH Certificate for Host"
         echo "  generateClientSSHCert   Generates SSH Certificate for Client"
         echo ""
         echo "Parameters:"
         echo "  ENVIRONMENT             Environment to use (default: client)"
         echo "  AWS PROFILE             AWS profile to use (default: default)"
         echo "  USER SSH DIR            Path to user's SSH directory (default: /home/$USER/.ssh)"
         echo "  USER AWS DIR            Path to user's AWS directory (default: /home/$USER/.aws)"
         echo "  SYSTEM SSH DIR          Path to system's SSH directory (default: /etc/ssh)"
         echo "  AWS STS REGION          AWS region for STS operations (default: ap-southeast-1)"
         exit;;
      *)
         echo "Error: Invalid option"
         exit;;
   esac
done


if [[ $CA_ACTION = "generateClientSSHCert" ]]; then
    [[ -d "${USER_SSH_DIR}" ]] || { echo "User SSH directory does not exist. Please provide the correct user SSH directory."; exit 1; }

    # Check if a valid certificate exists
    CERT_VALID=false
    if test -f ${USER_SSH_DIR}/id_rsa-cert.pub; then
        # Client SSH Certificate already exists
        current_timestamp=$(date -u +%s) 
        certificate_expiration_timestamp=$(TZ=UTC ssh-keygen -Lf ${USER_SSH_DIR}/id_rsa-cert.pub 2>/dev/null | awk '/Valid:/{print $NF}')

        if [[ $certificate_expiration_timestamp > $current_timestamp ]]; then
            # Certificate is valid
            if [[ -f "${USER_SSH_DIR}/known_hosts" ]]; then
                if grep -qE '^@cert-authority .* fundwave_host_ca$' "${USER_SSH_DIR}/known_hosts"; then
                    CERT_VALID=true
                    echo "A valid user certificate and known_hosts entry were found."
                else
                    echo "User certificate is valid, but known_hosts entry is missing."
                fi
            else
                echo "User certificate is valid, but known_hosts file is missing."
            fi
        else
            echo "Existing user certificate is expired or invalid."
            rm -f ${USER_SSH_DIR}/id_rsa-cert.pub
        fi
    fi
    test -f ${USER_SSH_DIR}/id_rsa.pub || {
        ssh-keygen -t rsa -b 4096 -f ${USER_SSH_DIR}/id_rsa -N ""
        [[ -f ${USER_SSH_DIR}/id_rsa-cert.pub ]] && rm ${USER_SSH_DIR}/id_rsa-cert.pub
    }
    CERT_PUBKEY=$(cat ${USER_SSH_DIR}/id_rsa.pub | base64 | tr -d \\n)

    get_aws_credentials
    prepare_event_json
    invoke_lambda

    HOST_CA_PUBKEY=$(echo $response_body | jq -r ".\"host_ca.pub\"" | base64 -d)

    safe_replace_old_certificate "$CERTIFICATE" "${USER_SSH_DIR}/id_rsa-cert.pub"

    [[ -f "${USER_SSH_DIR}/known_hosts" ]] || touch "${USER_SSH_DIR}/known_hosts"

    # Add host CA public key to known_hosts file if it doesn't exist and update it if it does
    # @cert-authority tells ssh to trust the host CA public key
    # ${HOST_CA_PUBKEY} is the host CA public key that was used to sign the host certificate
    if grep -qE '^@cert-authority .* fundwave_host_ca$' "${USER_SSH_DIR}/known_hosts"; then
        # Update existing line
        sed -i.bak -E "s|^(@cert-authority .*) ssh-rsa .*|\1 ${HOST_CA_PUBKEY}|" "${USER_SSH_DIR}/known_hosts"
    else
        # * means all hosts (wildcard) (you can also specify a list of comma separated hostnames)
        echo "@cert-authority * ${HOST_CA_PUBKEY}" >> "${USER_SSH_DIR}/known_hosts"
    fi

elif [[ $CA_ACTION = "generateHostSSHCert" ]]; then
    # Host certificate generation is not allowed in client environment
    if [[ $ENVIRONMENT = "client" ]]; then
        echo -e "\nError: generateHostSSHCert is not allowed in client environment.\nHost certificate generation requires host (server) environment.\n"
        exit 1
    fi
    if [ "$EUID" -ne 0 ]; then
        echo "Run this script with sudo or as root for generating host certificate."
        exit 1
    fi
    
    # Check if a valid certificate exists
    CERT_VALID=false
    if test -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub; then
        current_timestamp=$(date -u +%s) 
        certificate_expiration_timestamp=$(TZ=UTC ssh-keygen -Lf ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub 2>/dev/null | awk '/Valid:/{print $NF}')
        [[ $(uname) == "Darwin" ]] && cert_expiry_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$certificate_expiration_timestamp" +"%s") || cert_expiry_epoch=$(date -d "$certificate_expiration_timestamp" +"%s")
        next_run_timestamp=$((current_timestamp + CERT_HALF_LIFE_SECONDS))

        if [[ $cert_expiry_epoch -gt $next_run_timestamp ]]; then
            CERT_VALID=true
            echo "A valid host certificate was found at ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub."
        else
            echo "Existing host certificate will expire before next cron run."
            rm -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub
        fi
    fi
    
    test -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key.pub || {
        ssh-keygen -t rsa -b 4096 -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key -N ""
        [[ -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub ]] && rm ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub
    }
    CERT_PUBKEY=$(cat ${SYSTEM_SSH_DIR}/ssh_host_rsa_key.pub | base64 | tr -d \\n)

    get_aws_credentials
    prepare_event_json
    invoke_lambda

    USER_CA_PUBKEY=$(echo $response_body | jq -r ".\"user_ca.pub\"" | base64 -d)
    
    safe_replace_old_certificate "$CERTIFICATE" "${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub"

    [[ -f "${SYSTEM_SSH_DIR}/user_ca.pub" ]] || touch "${SYSTEM_SSH_DIR}/user_ca.pub"

    if grep -qE '.* fundwave_user_ca$' "${SYSTEM_SSH_DIR}/user_ca.pub"; then
        # Update existing line
        sed -i.bak -E "s|ssh-rsa .* fundwave_user_ca$|${USER_CA_PUBKEY}|" "${SYSTEM_SSH_DIR}/user_ca.pub"
    else
        echo "${USER_CA_PUBKEY}" >> "${SYSTEM_SSH_DIR}/user_ca.pub"
    fi

    if [[ $(grep -q "HostCertificate" "${SYSTEM_SSH_DIR}/sshd_config"; echo $?) -ne 0 ]]; then
        echo "HostCertificate ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub" >> ${SYSTEM_SSH_DIR}/sshd_config
    fi

    if [[ $(grep -q "TrustedUserCAKeys" "${SYSTEM_SSH_DIR}/sshd_config"; echo $?) -ne 0 ]]; then
        echo "TrustedUserCAKeys ${SYSTEM_SSH_DIR}/user_ca.pub" >> ${SYSTEM_SSH_DIR}/sshd_config
    fi
    systemctl restart sshd

elif [[ $CA_ACTION = "getHostCAPublicKey" ]]; then
    get_aws_credentials
    prepare_event_json
    invoke_lambda

    HOST_CA_PUBKEY=$(echo $response_body | jq -r ".\"host_ca.pub\"" | base64 -d)

    [[ -f "${USER_SSH_DIR}/known_hosts" ]] || touch "${USER_SSH_DIR}/known_hosts"

    if grep -qE '^@cert-authority .* fundwave_host_ca$' "${USER_SSH_DIR}/known_hosts"; then
        sed -i.bak -E "s|^(@cert-authority .*) ssh-rsa .*|\1 ${HOST_CA_PUBKEY}|" "${USER_SSH_DIR}/known_hosts"
    else
        echo "@cert-authority * ${HOST_CA_PUBKEY}" >> "${USER_SSH_DIR}/known_hosts"
    fi
    echo "Host CA public key added to known_hosts."

fi

# Clean up
deactivate
