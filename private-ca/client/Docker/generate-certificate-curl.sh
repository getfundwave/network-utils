#!/bin/bash

CA_ACTION=${1:-$CA_ACTION}
CA_LAMBDA_URL=${2:-$CA_LAMBDA_URL}
USER_SSH_DIR=${3:-"/home/$USER/.ssh"}
SYSTEM_SSH_DIR=${4:-"/etc/ssh"}
SYSTEM_SSL_DIR=${5:-"/etc/ssl"}
AWS_STS_REGION=${6:-"ap-southeast-1"}
AWS_PROFILE=${7:-"default"}

PYTHON_EXEC=$(which python || which python3)

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
        current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S") 
        certificate_expiration_timestamp=$(ssh-keygen -Lf ${USER_SSH_DIR}/id_rsa-cert.pub | awk '/Valid:/{print $NF}')

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
    if test -f ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub; then
        # Host SSH Certificate already exists
        current_timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S") 
        certificate_expiration_timestamp=$(ssh-keygen -Lf ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub | awk '/Valid:/{print $NF}')

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

elif [[ $CA_ACTION = "generateClientX509Cert" ]]; then
    test -d ${SYSTEM_SSL_DIR}/privateCA || mkdir -p ${SYSTEM_SSL_DIR}/privateCA
    if test -f ${SYSTEM_SSL_DIR}/privateCA/public.crt; then
        # X.509 Certificate already exists

        if ( openssl x509 -checkend 300 -noout -in ${SYSTEM_SSL_DIR}/privateCA/public.crt ); then
            # Certificate is valid for atleast 300 seconds (5 minutes)
            echo "A valid certificate was found at ${SYSTEM_SSL_DIR}/privateCA/public.crt."
            echo "Aborting..."
            exit;
        else
            # Certificate expired or about to expire
            rm ${SYSTEM_SSL_DIR}/privateCA/public.crt
        fi
    fi
    if ! test -f ${SYSTEM_SSL_DIR}/privateCA/public.pem; then
        openssl genrsa -out ${SYSTEM_SSL_DIR}/privateCA/key.pem 2048
        openssl rsa -in ${SYSTEM_SSL_DIR}/privateCA/key.pem -outform PEM -pubout -out ${SYSTEM_SSL_DIR}/privateCA/public.pem
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
INSTANCE_ROLE_NAME=$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/)
TEMP_CREDS=$(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/$INSTANCE_ROLE_NAME)

ACCESS_KEY_ID=$(echo $TEMP_CREDS | jq -r ".AccessKeyId")
SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | jq -r ".SecretAccessKey")
SESSION_TOKEN=$(echo $TEMP_CREDS | jq -r ".Token")

# Auth Headers
output=$($PYTHON_EXEC aws-auth-header.py $ACCESS_KEY_ID $SECRET_ACCESS_KEY $SESSION_TOKEN $AWS_STS_REGION)
auth_header=$(echo $output | jq -r ".Authorization")
date=$(echo $output | jq -r ".Date")

EVENT_JSON=$(echo "{\"auth\":{\"amzDate\":\"${date}\",\"authorizationHeader\":\"${auth_header}\",\"sessionToken\":\"${SESSION_TOKEN}\"},\"certPubkey\":\"${CERT_PUBKEY}\",\"action\":\"${CA_ACTION}\",\"awsSTSRegion\":\"${AWS_STS_REGION}\"}")

if [[ $CA_ACTION = "generateClientSSHCert" ]]; then
    LAMBDA_RESPONSE=$(curl "${CA_LAMBDA_URL}" -H 'content-type: application/json' -d "$EVENT_JSON")
    ENCODED_CERTIFICATE=$(echo $LAMBDA_RESPONSE | jq -r ".certificate")
    CERTIFICATE=$(echo $ENCODED_CERTIFICATE | base64 -d)
    HOST_CA_PUBKEY=$(echo $LAMBDA_RESPONSE | jq -r ".\"host_ca.pub\"" | base64 -d)

    echo $CERTIFICATE > ${USER_SSH_DIR}/id_rsa-cert.pub
    echo "Certificate written to ${USER_SSH_DIR}/id_rsa-cert.pub"

    if [[ $(grep -q "@cert-authority" "${USER_SSH_DIR}/known_hosts"; echo $?) -ne 0 ]]; then
        echo "@cert-authority * ${HOST_CA_PUBKEY}" >> ${USER_SSH_DIR}/known_hosts
    fi

elif [[ $CA_ACTION = "generateHostSSHCert" ]]; then
    LAMBDA_RESPONSE=$(curl "${CA_LAMBDA_URL}" -H 'content-type: application/json' -d "$EVENT_JSON")
    ENCODED_CERTIFICATE=$(echo $LAMBDA_RESPONSE | jq -r ".certificate")
    CERTIFICATE=$(echo $ENCODED_CERTIFICATE | base64 -d)    
    USER_CA_PUBKEY=$(echo $LAMBDA_RESPONSE | jq -r ".\"user_ca.pub\"" | base64 -d)

    sh -c "echo $CERTIFICATE > ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub"
    echo "Certificate written to ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub"

    test -f ${SYSTEM_SSH_DIR}/user_ca.pub || echo $USER_CA_PUBKEY > ${SYSTEM_SSH_DIR}/user_ca.pub

    if [[ $(grep -q "HostCertificate" "${SYSTEM_SSH_DIR}/sshd_config"; echo $?) -ne 0 ]]; then
        echo "HostCertificate ${SYSTEM_SSH_DIR}/ssh_host_rsa_key-cert.pub" >> ${SYSTEM_SSH_DIR}/sshd_config
    fi

    if [[ $(grep -q "TrustedUserCAKeys" "${SYSTEM_SSH_DIR}/sshd_config"; echo $?) -ne 0 ]]; then
        echo "TrustedUserCAKeys ${SYSTEM_SSH_DIR}/user_ca.pub" >> ${SYSTEM_SSH_DIR}/sshd_config
    fi
elif [[ $CA_ACTION = "generateClientX509Cert" ]]; then
    ENCODED_CERTIFICATE=$(curl "${CA_LAMBDA_URL}" -H 'content-type: application/json' -d "$EVENT_JSON" | tr -d '"')
    CERTIFICATE=$(echo $ENCODED_CERTIFICATE | base64 -d)
    sh -c "echo '$CERTIFICATE' > ${SYSTEM_SSL_DIR}/privateCA/public.crt"
    echo "Certificate written to ${SYSTEM_SSL_DIR}/privateCA/public.crt"
fi
