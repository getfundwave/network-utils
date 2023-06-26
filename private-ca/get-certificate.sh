#!/bin/bash

CA_ACTION=${1}
CERT_PUBKEY=${2}
CERT_VALIDITY=${3:-"1"}
AWS_STS_REGION=${4:-"ap-south-1"}
AWS_SECRETS_REGION=${5:-"ap-south-1"}
CA_LAMBDA_FUNCTION_NAME=${6:-"privateCA"}

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

echo "{\"auth\": {
        \"amzDate\": \"${date}\", 
        \"authorizationHeader\": \"${auth_header}\", 
        \"sessionToken\": \"${SESSION_TOKEN}\"
    },
    \"certValidity\": \"${CERT_VALIDITY}\",
    \"certPubkey\": \"${CERT_PUBKEY}\",
    \"action\": \"${CA_ACTION}\",
    \"awsSTSRegion\": \"${AWS_STS_REGION}\",
    \"awsSecretsRegion\": \"${AWS_SECRETS_REGION}\"
    }" > event.json


aws lambda invoke --function-name ${CA_LAMBDA_FUNCTION_NAME} --cli-binary-format raw-in-base64-out --payload file://event.json response.json
response_body=$(cat response.json | jq -r ".body" | tr -d '"' | sed 's/\\r\\n/ \
/g')

echo ${response_body}

# Clean up
deactivate
sudo rm -r env/ event.json