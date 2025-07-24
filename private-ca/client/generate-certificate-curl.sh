#!/bin/bash

CA_ACTION=${1:-$CA_ACTION}
CA_URL=${2:-$CA_URL}
ENVIRONMENT=${3:-"client"}
USER_SSH_DIR=${4:-"$HOME/.ssh"}
USER_AWS_DIR=${5:-"$HOME/.aws"}
SYSTEM_SSH_DIR=${6:-"/etc/ssh"}
AWS_STS_REGION=${7:-"ap-southeast-1"}
AWS_EC2_REGION=${8:-"us-west-2"}

PYTHON_EXEC=$(which python 2>/dev/null || which python3 2>/dev/null)
[[ $? -ne 0 ]] && { echo "Python binary not found."; exit 1; }

trap 'clean_config_on_error' EXIT

clean_config_on_error() {
    if [[ $? -ne 0 && $CA_ACTION == "generateHostSSHCert" && $CERT_VALID == "false" ]]; then
        echo "Error occurred. Cleaning host SSH config..."
        sed -i "\|^HostCertificate ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub\$|d"  ${SYSTEM_SSH_DIR}/sshd_config
        sed -i "\|^TrustedUserCAKeys ${SYSTEM_SSH_DIR}/user_ca.pub\$|d"  ${SYSTEM_SSH_DIR}/sshd_config

        rm ${SYSTEM_SSH_DIR}/user_ca.pub
        rm ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub
        systemctl restart sshd
        echo "Host SSH config cleaned."
    fi
}

get_aws_credentials() {
    local method=${1:-"host"}
    local TEMP_CREDS

    if [[ $method == "host" ]]; then
        TOKEN=$(curl -s --max-time 30 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 120")

        if [[ -z "$TOKEN" ]]; then
            echo "Failed to fetch EC2 metadata token. Are you running this script on an EC2 instance?"
            exit 1
        fi

        INSTANCE_ROLE_NAME=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/)
        TEMP_CREDS=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/$INSTANCE_ROLE_NAME)
        
    elif [[ $method == "client" ]]; then
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

# Check for options
while getopts ":h" option; do
   case $option in
      h)
         echo "Usage: ./generate-certificate.sh [ACTION] [CA URL] [ENVIRONMENT] [AWS PROFILE] [USER SSH DIR] [USER AWS DIR] [SYSTEM SSH DIR] [AWS STS REGION]"
         echo "Possible actions:"
         echo " generateHostSSHCert: Generates SSH Certificate for Host"
         echo " generateClientSSHCert: Generates SSH Certificate for Client"
         exit;;
      *)
         echo "Error: Invalid option"
         exit;;
   esac
done

# Check for CA Action
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
                    echo "A valid certificate and known_hosts entry were found."
                else
                    echo "Certificate is valid, but known_hosts entry is missing."
                fi
            else
                echo "Certificate is valid, but known_hosts file is missing."
            fi
        else
            echo "Existing certificate is expired or invalid."
            rm -f ${USER_SSH_DIR}/id_rsa-cert.pub
        fi
    fi
    test -f ${USER_SSH_DIR}/id_rsa.pub || {
        ssh-keygen -t rsa -b 4096 -f ${USER_SSH_DIR}/id_rsa -N ""
        [[ -f ${USER_SSH_DIR}/id_rsa-cert.pub ]] && rm ${USER_SSH_DIR}/id_rsa-cert.pub
    }
    CERT_PUBKEY=$(cat ${USER_SSH_DIR}/id_rsa.pub | base64 | tr -d \\n)

elif [[ $CA_ACTION = "generateHostSSHCert" ]]; then
    # Host certificate generation is not allowed in client environment
    if [[ $ENVIRONMENT = "client" ]]; then
        echo -e "\nError: generateHostSSHCert is not allowed in client environment.\nHost certificate generation requires host/server environment.\n"
        exit 1
    fi
    if [ "$EUID" -ne 0 ]; then
        echo "Run this script with sudo or as root for generating host certificate."
        exit 1
    fi
    
    # Check if a valid certificate exists
    CERT_VALID=false
    half_life_seconds=259200 # 3 days
    if test -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub; then
        current_timestamp=$(date -u +%s) 
        certificate_expiration_timestamp=$(TZ=UTC ssh-keygen -Lf ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub 2>/dev/null | awk '/Valid:/{print $NF}')
        [[ $(uname) == "Darwin" ]] && cert_expiry_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$certificate_expiration_timestamp" +"%s") || cert_expiry_epoch=$(date -d "$certificate_expiration_timestamp" +"%s")
        next_run_timestamp=$((current_timestamp + half_life_seconds))

        if [[ $cert_expiry_epoch -gt $next_run_timestamp ]]; then
            CERT_VALID=true
            echo "A valid certificate was found at ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub."
        else
            echo "Existing certificate will expire before next cron run."
            rm -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub
        fi
    fi
    
    test -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key.pub || {
        ssh-keygen -t rsa -b 4096 -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key -N ""
        [[ -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub ]] && rm ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub
    }
    CERT_PUBKEY=$(cat ${SYSTEM_SSH_DIR}/ssh_host_rsa_key.pub | base64 | tr -d \\n)
else
    echo "Invalid Action"
    echo "Possible actions include:"
    echo " generateHostSSHCert: Generates SSH Certificate for Host"
    echo " generateClientSSHCert: Generates SSH Certificate for Client"
    exit 1;
fi

get_aws_credentials $ENVIRONMENT

if [ ! -d "private-ca-client-env" ]; then
  $PYTHON_EXEC -m venv private-ca-client-env
fi
source ./private-ca-client-env/bin/activate
pip install -q --upgrade --disable-pip-version-check boto3

# Update PYTHON_EXEC to use the Python executable from the activated virtual environment
# This ensures we use the venv's Python with the installed dependencies (boto3)
PYTHON_EXEC=$(which python 2>/dev/null || which python3 2>/dev/null)

# Auth Headers
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

EVENT_JSON=$(echo "{\"auth\":{\"amzDate\":\"${date}\",\"authorizationHeader\":\"${auth_header}\",\"sessionToken\":\"${SESSION_TOKEN}\"},\"certPubkey\":\"${CERT_PUBKEY}\",\"action\":\"${CA_ACTION}\",\"awsSTSRegion\":\"${AWS_STS_REGION}\",\"awsEC2Region\":\"${AWS_EC2_REGION}\"}")


if [[ $CA_ACTION = "generateClientSSHCert" ]]; then
    read -r STATUS_CODE LAMBDA_RESPONSE < <(
        curl -s "${CA_URL}" -H 'content-type: application/json' -d "$EVENT_JSON" -w "%{http_code}\n" | 
        { 
            response=$(cat)
            status_code=${response: -3}
            body=${response:0:$((${#response}-3))}
            echo "$status_code $body"
        }
    )

    if [[ "$STATUS_CODE" != "200" ]]; then
        echo "CA request failed (Status: ${STATUS_CODE}): ${LAMBDA_RESPONSE}"
        if [[ "$CERT_VALID" == "true" ]]; then
            echo "Keeping existing valid certificate."
        fi
        exit 1;
    fi
    
    ENCODED_CERTIFICATE=$(echo "$LAMBDA_RESPONSE" | jq -er ".certificate") || {
        echo "Certificate not found in Lambda response. Aborting.";
        if [[ "$CERT_VALID" == "true" ]]; then
            echo "Keeping existing valid certificate."
        fi
        exit 1;
    }
    
    CERTIFICATE=$(echo $ENCODED_CERTIFICATE | base64 -d)
    HOST_CA_PUBKEY=$(echo $LAMBDA_RESPONSE | jq -r ".\"host_ca.pub\"" | base64 -d)

    if [[ -z "$CERTIFICATE" ]]; then
        echo "Empty certificate received. Not writing to disk."
        if [[ "$CERT_VALID" == "true" ]]; then
            echo "Keeping existing valid certificate."
        fi
        exit 1
    fi

    # Write new certificate to temporary file first
    TEMP_CERT_FILE="${USER_SSH_DIR}/id_rsa-cert.pub.tmp"
    echo "$CERTIFICATE" > "$TEMP_CERT_FILE"
    
    # Verify the new certificate is valid
    if ssh-keygen -Lf "$TEMP_CERT_FILE" >/dev/null 2>&1; then
        # New certificate is valid, replace the old one
        mv "$TEMP_CERT_FILE" "${USER_SSH_DIR}/id_rsa-cert.pub"
        echo "New certificate written to ${USER_SSH_DIR}/id_rsa-cert.pub"
        CERT_VALID=true
    else
        # New certificate is invalid
        rm -f "$TEMP_CERT_FILE"
        echo "Generated certificate is invalid. Discarding."
        if [[ "$CERT_VALID" == "true" ]]; then
            echo "Keeping existing valid certificate."
        fi
        exit 1
    fi

    [[ -f "${USER_SSH_DIR}/known_hosts" ]] || touch "${USER_SSH_DIR}/known_hosts"

    # Add host CA public key to known_hosts file if it doesn't exist and update it if it does
    # @cert-authority tells ssh to trust the host CA public key
    # ${HOST_CA_PUBKEY} is the host CA public key that was used to sign the host certificate
    if grep -qE '^@cert-authority .* fundwave_host_ca$' "${USER_SSH_DIR}/known_hosts"; then
        # Update existing line
        sed -i.bak -E "s|^(@cert-authority .*) ssh-rsa .*|\1 ${HOST_CA_PUBKEY}|" "${USER_SSH_DIR}/known_hosts"
    else
        # Add new line
        # * means all hosts (wildcard) (you can also specify a list of comma separated hostnames)
        echo "@cert-authority * ${HOST_CA_PUBKEY}" >> "${USER_SSH_DIR}/known_hosts"
    fi

# sudo access is required to generate host certificate
elif [[ $CA_ACTION = "generateHostSSHCert" ]]; then
    read -r STATUS_CODE LAMBDA_RESPONSE < <(
        curl -s "${CA_URL}" -H 'content-type: application/json' -d "$EVENT_JSON" -w "%{http_code}\n" | 
        { 
            response=$(cat)
            status_code=${response: -3}
            body=${response:0:$((${#response}-3))}
            echo "$status_code $body"
        }
    )

    if [[ "$STATUS_CODE" != "200" ]]; then
        echo "CA request failed (Status: ${STATUS_CODE}): ${LAMBDA_RESPONSE}"
        if [[ "$CERT_VALID" == "true" ]]; then
            echo "Keeping existing valid certificate."
        fi
        exit 1;
    fi
    
    ENCODED_CERTIFICATE=$(echo "$LAMBDA_RESPONSE" | jq -er ".certificate") || {
        echo "Certificate not found in Lambda response. Aborting.";
        if [[ "$CERT_VALID" == "true" ]]; then
            echo "Keeping existing valid certificate."
        fi
        exit 1;
    }
    
    CERTIFICATE=$(echo $ENCODED_CERTIFICATE | base64 -d)    
    USER_CA_PUBKEY=$(echo $LAMBDA_RESPONSE | jq -r ".\"user_ca.pub\"" | base64 -d)

    if [[ -z "$CERTIFICATE" ]]; then
        echo "Empty certificate received. Not writing to disk."
        if [[ "$CERT_VALID" == "true" ]]; then
            echo "Keeping existing valid certificate."
        fi
        exit 1
    fi

    # Write new certificate to temporary file first
    TEMP_CERT_FILE="${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub.tmp"
    echo "$CERTIFICATE" > "$TEMP_CERT_FILE"
    
    # Verify the new certificate is valid
    if ssh-keygen -Lf "$TEMP_CERT_FILE" >/dev/null 2>&1; then
        # New certificate is valid, replace the old one
        mv "$TEMP_CERT_FILE" "${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub"
        echo "New certificate written to ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub"
        CERT_VALID=true
    else
        # New certificate is invalid
        rm -f "$TEMP_CERT_FILE"
        echo "Generated certificate is invalid. Discarding."
        if [[ "$CERT_VALID" == "true" ]]; then
            echo "Keeping existing valid certificate."
        fi
        exit 1
    fi

    [[ -f "${SYSTEM_SSH_DIR}/user_ca.pub" ]] || touch "${SYSTEM_SSH_DIR}/user_ca.pub"

    if grep -qE '.* fundwave_user_ca$' "${SYSTEM_SSH_DIR}/user_ca.pub"; then
        # Update existing line
        sed -i.bak -E "s|ssh-rsa .* fundwave_user_ca$|${USER_CA_PUBKEY}|" "${SYSTEM_SSH_DIR}/user_ca.pub"
    else
        # Add new line
        # * means all hosts (wildcard) (you can also specify a list of comma separated hostnames)
        echo "${USER_CA_PUBKEY}" >> "${SYSTEM_SSH_DIR}/user_ca.pub"
    fi

    if [[ $(grep -q "HostCertificate" "${SYSTEM_SSH_DIR}/sshd_config"; echo $?) -ne 0 ]]; then
        echo "HostCertificate ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub" >> ${SYSTEM_SSH_DIR}/sshd_config
    fi

    if [[ $(grep -q "TrustedUserCAKeys" "${SYSTEM_SSH_DIR}/sshd_config"; echo $?) -ne 0 ]]; then
        echo "TrustedUserCAKeys ${SYSTEM_SSH_DIR}/user_ca.pub" >> ${SYSTEM_SSH_DIR}/sshd_config
    fi
    systemctl restart sshd
fi

deactivate