#!/bin/bash
set -eo pipefail
trap 'echo "Error occurred on line $LINENO. Exiting."; exit 1;' ERR

CA_ACTION=${1:-"generateHostSSHCert"}
ENVIRONMENT=${2:-"client"}
AWS_PROFILE=${3:-"default"}
USER_SSH_DIR=${4:-"/home/$USER/.ssh"}
USER_AWS_DIR=${5:-"/home/$USER/.aws"}
SYSTEM_SSH_DIR=${6:-"/etc/ssh"}
LAMBDA_REGION=${7:-'us-west-2'}
CA_LAMBDA_FUNCTION_NAME=${8:-"privateCA"}
AWS_STS_REGION=${9:-"ap-southeast-1"}
AWS_EC2_REGION=${10:-"us-west-2"}

PYTHON_EXEC=$(which python 2>/dev/null || which python3 2>/dev/null)
[[ $? -ne 0 ]] && { echo "Python binary not found."; exit 1; }

is_mfa_enabled() {
  grep -q 'get-credentials' ${USER_AWS_DIR}/credentials
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
        if is_mfa_enabled; then
            CALLER_IDENTITY=$(aws sts get-caller-identity --profile $AWS_PROFILE)
            [[ $? -ne 0 ]] && { echo "Your AWS credentials have either expired or are invalid. Please check your credentials and try again."; exit 1; }

            TEMP_CREDS=$(get-credentials $AWS_PROFILE)
        else
            TEMP_CREDS=$(aws sts get-session-token --profile $AWS_PROFILE | jq -r ".Credentials")
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

# Check for CA Action
if [[ $CA_ACTION = "generateClientSSHCert" ]]; then

    [[ -d "${USER_SSH_DIR}" ]] || { echo "User SSH directory does not exist. Please provide the correct user SSH directory."; exit 1; }

    if test -f ${USER_SSH_DIR}/id_rsa-cert.pub; then
        # Client SSH Certificate already exists
        current_timestamp=$(TZ=UTC date -u +"%Y-%m-%dT%H:%M:%S") 
        certificate_expiration_timestamp=$(TZ=UTC ssh-keygen -Lf ${USER_SSH_DIR}/id_rsa-cert.pub | awk '/Valid:/{print $NF}')

        if [[ $certificate_expiration_timestamp > $current_timestamp ]]; then
            # Certificate is valid
            echo "A valid certificate was found at ${USER_SSH_DIR}/id_rsa-cert.pub."
            echo "Aborting..."
            exit;
        else
            # Certificate expired
            rm ${USER_SSH_DIR}/id_rsa-cert.pub
        fi
    fi
    test -f ${USER_SSH_DIR}/id_rsa.pub || ssh-keygen -t rsa -b 4096 -f ${USER_SSH_DIR}/id_rsa -C host_ca -N ""
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
    
    if test -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub; then
        # Host SSH Certificate already exists
        current_timestamp=$(TZ=UTC date -u +"%Y-%m-%dT%H:%M:%S") 
        certificate_expiration_timestamp=$(TZ=UTC ssh-keygen -Lf ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub | awk '/Valid:/{print $NF}')

        if [[ $certificate_expiration_timestamp > $current_timestamp ]]; then
            # Certificate is valid 
            echo "A valid certificate was found at ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub."
            echo "Aborting..."
            exit;
        else
            # Certificate expired
            rm ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub
        fi
    fi
    test -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key.pub || ssh-keygen -t rsa -b 4096 -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key -C host_ca -N ""
    CERT_PUBKEY=$(cat ${SYSTEM_SSH_DIR}/ssh_host_rsa_key.pub | base64 | tr -d \\n)
else
    echo "Invalid Action"
    echo "Possible actions include:"
    echo " generateHostSSHCert: Generates SSH Certificate for Host"
    echo " generateClientSSHCert: Generates SSH Certificate for Client"
    exit 1;
fi

# Temporary Credentials
get_aws_credentials $ENVIRONMENT

if [ ! -d "private-ca-client-env" ]; then
  $PYTHON_EXEC -m venv private-ca-client-env
fi
source private-ca-client-env/bin/activate
pip install -q --upgrade boto3

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

# JSON with body as stringified JSON
json_body=$(jq -n --arg body "$INNER_JSON" '{body: $body}')
echo "$json_body" > event.json

# Use --profile only if AWS_PROFILE is set and ~/.aws/credentials exists
# On EC2 instances with IAM roles, credentials are fetched from instance metadata,
# and using --profile will cause an error if ~/.aws/credentials doesn't exist.
AWS_PROFILE_ARG=""
if [[ -n "$AWS_PROFILE" ]] && grep -q "$AWS_PROFILE" ${USER_AWS_DIR}/{credentials,config} 2>/dev/null; then
  AWS_PROFILE_ARG="--profile $AWS_PROFILE"
fi

aws lambda invoke \
    --function-name ${CA_LAMBDA_FUNCTION_NAME} \
    --cli-binary-format raw-in-base64-out \
    --payload file://event.json \
    response.json \
    --region $LAMBDA_REGION \
    $AWS_PROFILE_ARG

response_body=$(cat response.json | jq -r ".body") || {
    echo "Failed to parse response body.";
    exit 1;
}

if [[ $CA_ACTION = "generateClientSSHCert" ]]; then
    ENCODED_CERTIFICATE=$(echo "$response_body" | jq -er ".certificate") || {
        echo "Certificate not found in Lambda response. Aborting.";
        exit 1;
    }
    CERTIFICATE=$(echo $ENCODED_CERTIFICATE | base64 -d)
    HOST_CA_PUBKEY=$(echo $response_body | jq -r ".\"host_ca.pub\"" | base64 -d)

    echo $CERTIFICATE > ${USER_SSH_DIR}/id_rsa-cert.pub
    echo "Certificate written to ${USER_SSH_DIR}/id_rsa-cert.pub"

    [[ -f "${USER_SSH_DIR}/known_hosts" ]] || touch "${USER_SSH_DIR}/known_hosts"

    # Add host CA public key to known_hosts file if it doesn't exist
    if [[ $(grep -q "@cert-authority" "${USER_SSH_DIR}/known_hosts"; echo $?) -ne 0 ]]; then
        # @cert-authority tells ssh to trust the host CA public key
        # * means all hosts (wildcard) (you can also specify a list of comma separated hostnames)
        # ${HOST_CA_PUBKEY} is the host CA public key that was used to sign the host certificate
        echo "@cert-authority * ${HOST_CA_PUBKEY}" >> ${USER_SSH_DIR}/known_hosts
    fi

elif [[ $CA_ACTION = "generateHostSSHCert" ]]; then
    ENCODED_CERTIFICATE=$(echo "$response_body" | jq -er ".certificate") || {
        echo "Certificate not found in Lambda response. Aborting.";
        exit 1;
    }
    CERTIFICATE=$(echo $ENCODED_CERTIFICATE | base64 -d)    
    USER_CA_PUBKEY=$(echo $response_body | jq -r ".\"user_ca.pub\"" | base64 -d)
    
    if [[ -n "$CERTIFICATE" ]]; then
        echo "$CERTIFICATE" > "${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub"
        echo "Certificate written to ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub"
    else
        echo "Empty certificate received. Not writing to disk."
        exit 1
    fi

    test -f ${SYSTEM_SSH_DIR}/user_ca.pub || echo $USER_CA_PUBKEY > ${SYSTEM_SSH_DIR}/user_ca.pub

    if [[ $(grep -q "HostCertificate" "${SYSTEM_SSH_DIR}/sshd_config"; echo $?) -ne 0 ]]; then
        echo "HostCertificate ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub" >> ${SYSTEM_SSH_DIR}/sshd_config
    fi

    if [[ $(grep -q "TrustedUserCAKeys" "${SYSTEM_SSH_DIR}/sshd_config"; echo $?) -ne 0 ]]; then
        echo "TrustedUserCAKeys ${SYSTEM_SSH_DIR}/user_ca.pub" >> ${SYSTEM_SSH_DIR}/sshd_config
    fi
fi

# Clean up
deactivate
rm -r *.json
