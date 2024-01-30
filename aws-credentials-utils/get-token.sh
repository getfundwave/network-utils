#!/bin/bash

TOKEN=$1
DEVICE=$2
PROFILE=${3:-'default'}

if [ -z "$TOKEN" ] || [ -z "$DEVICE" ]; then
    echo "Usage [MFA-TOKEN] [ MFA DEVICE ] [ PROFILE (optional) ] "
    exit
fi

test -f "$HOME/.aws/credentials" && sed -i 's/get-credentials '$PROFILE'/get-credentials creds'$PROFILE' notoken/' ~/.aws/credentials

echo "Gettings credentials... "
CREDS=$(aws sts get-session-token --serial-number "$DEVICE" --token-code "$TOKEN" --duration-seconds 28800 --output json)

ACCESS_KEY=$(echo "$CREDS" | jq '.Credentials.AccessKeyId' | tr -d '"')
SECRET_ACCESS_KEY=$(echo "$CREDS" | jq '.Credentials.SecretAccessKey' | tr -d '"')
SESSION_TOKEN=$(echo "$CREDS" | jq '.Credentials.SessionToken' | tr -d '"')

CREDENTIALS="$ACCESS_KEY:$SECRET_ACCESS_KEY:$SESSION_TOKEN"

echo "$CREDENTIALS" | secret-tool store --label="AWS Account Access Key-Pair $PROFILE" provider aws profile "$PROFILE"
echo "Credentials set"

test -f "$HOME/.aws/credentials" && sed -i 's/get-credentials creds'$PROFILE' notoken/get-credentials '$PROFILE'/' ~/.aws/credentials
