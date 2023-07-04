#!/bin/bash

CA_ACTION=${1}
CERT_PUBKEY_FILE=${2}
CA_LAMBDA_URL=${3}
CERT_VALIDITY=${4:-"1"}
AWS_STS_REGION=${5:-"ap-south-1"}
AWS_SECRETS_REGION=${6:-"ap-south-1"}
CA_LAMBDA_FUNCTION_NAME=${7:-"privateCA"}

CERT_PUBKEY=$(cat ${CERT_PUBKEY_FILE} | base64 -w 0)

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

EVENT_JSON=$(echo "{\"auth\":{\"amzDate\":\"${date}\",\"authorizationHeader\":\"${auth_header}\",\"sessionToken\":\"${SESSION_TOKEN}\"},\"certValidity\":\"${CERT_VALIDITY}\",\"certPubkey\":\"${CERT_PUBKEY}\",\"action\":\"${CA_ACTION}\",\"awsSTSRegion\":\"${AWS_STS_REGION}\",\"awsSecretsRegion\":\"${AWS_SECRETS_REGION}\"}")

curl "${CA_LAMBDA_URL}" -H 'content-type: application/json' -d "$EVENT_JSON" | tr -d '"' | base64 -d > certificate

# Clean up
deactivate
sudo rm -r env/