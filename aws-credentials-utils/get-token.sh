#!/bin/bash

TOKEN=$1
DEVICE=$2
PROFILE=${3:-'<profile>'}

if [ -z "$TOKEN" ] || [ -z "$DEVICE" ]; then
  echo "Usage [MFA-TOKEN] [ MFA DEVICE ] [ PROFILE (optional) ] "
  exit
fi

if [ $(uname -o) == "GNU/Linux" ]; then
  SED_CMD="sed -i"
elif [ $(uname -o) == "Darwin" ]; then
  SED_CMD="sed -i ''"
fi 

test -f "$HOME/.aws/credentials" && ${SED_CMD} 's/get-credentials '$PROFILE'/get-credentials creds'$PROFILE' notoken/' ~/.aws/credentials

echo "Gettings credentials... "
CREDS=$(aws sts get-session-token --serial-number "$DEVICE" --token-code "$TOKEN" --duration-seconds 28800 --output json --profile "$PROFILE")

ACCESS_KEY=$(echo "$CREDS" | jq '.Credentials.AccessKeyId' -r)
SECRET_ACCESS_KEY=$(echo "$CREDS" | jq '.Credentials.SecretAccessKey' -r)
SESSION_TOKEN=$(echo "$CREDS" | jq '.Credentials.SessionToken' -r)

CREDENTIALS="$ACCESS_KEY:$SECRET_ACCESS_KEY:$SESSION_TOKEN"

if [ $(uname -o) == "GNU/Linux" ]; then
  printf $CREDENTIALS | secret-tool store --label="AWS Account Access Key-Pair $PROFILE" provider aws profile "$PROFILE"
elif [ $(uname -o) == "Darwin" ]; then
  security add-generic-password -s "AWS Account Access Key-Pair $PROFILE" -U -a $PROFILE -w $CREDENTIALS
fi 

echo "Credentials set"

test -f "$HOME/.aws/credentials" && ${SED_CMD} "s/get-credentials creds$PROFILE notoken/get-credentials $PROFILE/" ~/.aws/credentials
