#!/bin/bash

CA_LAMBDA_FUNCTION_NAME="privateCA"

# Edit values here
######################################################
# CA_ACTION="getHostSSHCert"
# CA_ACTION="getClientSSHCert"
CA_ACTION="generateRootX509Cert"
# CA_ACTION="generateClientX509Cert"

# # Get client SSL certificate
# SSL_ATTRS_VALIDITY=""
# SSL_CLIENT_PUBKEY_PEM=""

# # Get host SSH certificate
# SSH_ATTRS_VALIDITY=""
# SSH_HOST_RSA_PUBKEY=""

# # Get client SSH certificate
# SSH_ATTRS_VALIDITY=""
# SSH_CLIENT_RSA_PUBKEY=""
######################################################

# Temporary Credentials
TEMP_CREDS=$(aws sts get-session-token)

ACCESS_KEY_ID=$(echo $TEMP_CREDS | jq -r ".Credentials.AccessKeyId")
SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | jq -r ".Credentials.SecretAccessKey")
SESSION_TOKEN=$(echo $TEMP_CREDS | jq -r ".Credentials.SessionToken")

# Auth Headers
python -m venv env && source env/bin/activate
pip install boto3

output=$(python auth-header.py $ACCESS_KEY_ID $SECRET_ACCESS_KEY $SESSION_TOKEN)
auth_header=$(echo $output | jq -r ".Authorization")
date=$(echo $output | jq -r ".Date")

echo "{\"auth\": {
        \"amzDate\": \"${date}\", 
        \"authorizationHeader\": \"${auth_header}\", 
        \"sessionToken\": \"${SESSION_TOKEN}\"
    },
    \"sslAttrs\": {
        \"validityPeriod\": \"${SSL_ATTRS_VALIDITY}\",
        \"clientPublicKeyPem\": \"${SSL_CLIENT_PUBKEY_PEM}\"
    },
    \"sshAttrs\": {
        \"validity\": \"${SSH_ATTRS_VALIDITY}\",
        \"sshHostRSAKey\": \"${SSH_HOST_RSA_PUBKEY}\",
        \"sshClientRSAKey\": \"${SSH_CLIENT_RSA_PUBKEY}\"
    },
    \"action\": \"${CA_ACTION}\"
    }" > event.json


aws lambda invoke --function-name ${CA_LAMBDA_FUNCTION_NAME} --cli-binary-format raw-in-base64-out --payload file://event.json response.json
response_body=$(cat response.json | jq -r ".body" | tr -d '"' | sed 's/\\r\\n/ \
/g')

echo ${response_body}

# Clean up
deactivate
sudo rm -r env *.json