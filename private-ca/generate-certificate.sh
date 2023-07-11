#!/bin/bash

CA_ACTION=${1}
CA_LAMBDA_URL=${2}
USER_SSH_DIR=${3:-"/home/$USER/.ssh"}
SYSTEM_SSH_DIR=${4:-"/etc/ssh"}
SYSTEM_SSL_DIR=${5:-"/etc/ssl"}
AWS_STS_REGION=${6:-"ap-south-1"}
AWS_SECRETS_REGION=${7:-"ap-south-1"}
CA_LAMBDA_FUNCTION_NAME=${8:-"privateCA"}

# Check for options
while getopts ":h" option; do
   case $option in
      h)
         echo "Usage: ./generate-certificate.sh [ACTION] [PUBLIC KEY FILE] [LAMBDA URL]"
         echo "Possible actions:"
         echo " generateHostSSHCert: Generates SSH Certificate for Host"
         echo " generateClientSSHCert: Generates SSH Certificate for Client"
         echo " generateClientX509Cert: Generates X.509 Certificate for Client"
         exit;;
      *)
         echo "Error: Invalid option"
         exit;;
   esac
done

# Check for CA Action
if [[ $CA_ACTION = "generateClientSSHCert" ]]; then
    if test -f ${USER_SSH_DIR}/id_rsa-cert.pub; then
        # Client SSH Certificate already exists
        current_timestamp=$(date +%s) 
        certificate_expiration_timestamp=$(ssh-keygen -Lf ${USER_SSH_DIR}/id_rsa-cert.pub | awk '/Valid:/{print $NF}')
        certificate_expiration_timestamp_seconds=$(date -d "$certificate_expiration_timestamp" +%s)

        if (( certificate_expiration_timestamp_seconds > current_timestamp + 300 )); then
            # Certificate is valid for atleast 300 seconds (5 minutes)
            echo "A valid certificate was found at ${USER_SSH_DIR}/id_rsa-cert.pub."
            echo "Aborting..."
            exit;
        else
            # Certificate expired or about to expire
            rm ${USER_SSH_DIR}/id_rsa-cert.pub
        fi
    fi
    test -f ${USER_SSH_DIR}/id_rsa.pub || ssh-keygen -t rsa -b 4096 -f ${USER_SSH_DIR}/id_rsa -C host_ca -N ""
    CERT_PUBKEY=$(cat ${USER_SSH_DIR}/id_rsa.pub | base64 | tr -d \\n)

elif [[ $CA_ACTION = "generateHostSSHCert" ]]; then
    if test -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub; then
        # Host SSH Certificate already exists
        current_timestamp=$(date +%s) 
        certificate_expiration_timestamp=$(ssh-keygen -Lf ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub | awk '/Valid:/{print $NF}')
        certificate_expiration_timestamp_seconds=$(echo "$certificate_expiration_timestamp" | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')

        if (( certificate_expiration_timestamp_seconds > current_timestamp + 300)); then
            # Certificate is valid for atleast 300 seconds (5 minutes)
            echo "A valid certificate was found at ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub."
            echo "Aborting..."
            exit;
        else
            # Certificate expired or about to expire
            rm ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub
        fi
    fi
    test -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key.pub || ssh-keygen -t rsa -b 4096 -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key -C host_ca -N ""
    CERT_PUBKEY=$(cat ${SYSTEM_SSH_DIR}/ssh_host_rsa_key.pub | base64 | tr -d \\n)

elif [[ $CA_ACTION = "generateClientX509Cert" ]]; then
    test -d ${SYSTEM_SSL_DIR}/privateCA || sudo mkdir -p ${SYSTEM_SSL_DIR}/privateCA
    if test -f ${SYSTEM_SSL_DIR}/privateCA/public.crt; then
        # X.509 Certificate already exists

        if ( sudo openssl x509 -checkend 300 -noout -in ${SYSTEM_SSL_DIR}/privateCA/public.crt ); then
            # Certificate is valid for atleast 300 seconds (5 minutes)
            echo "A valid certificate was found at ${SYSTEM_SSL_DIR}/privateCA/public.crt."
            echo "Aborting..."
            exit;
        else
            # Certificate expired or about to expire
            sudo rm ${SYSTEM_SSL_DIR}/privateCA/public.crt
        fi
    fi
    if ! test -f ${SYSTEM_SSL_DIR}/privateCA/public.pem; then
        sudo openssl genrsa -out ${SYSTEM_SSL_DIR}/privateCA/key.pem 2048
        sudo openssl rsa -in ${SYSTEM_SSL_DIR}/privateCA/key.pem -outform PEM -pubout -out ${SYSTEM_SSL_DIR}/privateCA/public.pem
    fi
    CERT_PUBKEY=$(cat ${SYSTEM_SSL_DIR}/privateCA/public.pem | base64 | tr -d \\n)
else
    echo "Invalid Action"
    echo "Possible actions include:"
    echo " generateHostSSHCert: Generates SSH Certificate for Host"
    echo " generateClientSSHCert: Generates SSH Certificate for Client"
    echo " generateClientX509Cert: Generates X.509 Certificate for Client"
    exit;
fi

# Temporary Credentials
TEMP_CREDS=$(aws sts get-session-token)

ACCESS_KEY_ID=$(echo $TEMP_CREDS | jq -r ".Credentials.AccessKeyId")
SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | jq -r ".Credentials.SecretAccessKey")
SESSION_TOKEN=$(echo $TEMP_CREDS | jq -r ".Credentials.SessionToken")

# Auth Headers
python -m venv env && source env/bin/activate
pip install boto3

output=$(python aws-auth-header.py $ACCESS_KEY_ID $SECRET_ACCESS_KEY $SESSION_TOKEN $AWS_STS_REGION)
auth_header=$(echo $output | jq -r ".Authorization")
date=$(echo $output | jq -r ".Date")

EVENT_JSON=$(echo "{\"auth\":{\"amzDate\":\"${date}\",\"authorizationHeader\":\"${auth_header}\",\"sessionToken\":\"${SESSION_TOKEN}\"},\"certPubkey\":\"${CERT_PUBKEY}\",\"action\":\"${CA_ACTION}\",\"awsSTSRegion\":\"${AWS_STS_REGION}\",\"awsSecretsRegion\":\"${AWS_SECRETS_REGION}\"}")

ENCODED_CERTIFICATE=$(curl "${CA_LAMBDA_URL}" -H 'content-type: application/json' -d "$EVENT_JSON" | tr -d '"')
CERTIFICATE=$(echo $ENCODED_CERTIFICATE | base64 -d)


if [[ $CA_ACTION = "generateClientSSHCert" ]]; then
    echo $CERTIFICATE > ${USER_SSH_DIR}/id_rsa-cert.pub
    echo "Certificate written to ${USER_SSH_DIR}/id_rsa-cert.pub"
elif [[ $CA_ACTION = "generateHostSSHCert" ]]; then
    sudo sh -c "echo $CERTIFICATE > ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub"
    echo "Certificate written to ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub"
elif [[ $CA_ACTION = "generateClientX509Cert" ]]; then
    sudo sh -c "echo '$CERTIFICATE' > ${SYSTEM_SSL_DIR}/privateCA/public.crt"
    echo "Certificate written to ${SYSTEM_SSL_DIR}/privateCA/public.crt"
fi

# Clean up
deactivate
rm -r env/