#!/bin/bash

PROFILE=${1:-'default'}

CREDENTIALS=$(secret-tool lookup provider aws profile $PROFILE)

# echo $access_key
ACCESS_KEY_ID=$(echo "$CREDENTIALS" | awk -F':' '{ print $1 }' )
SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | awk -F':' '{ print $2 }')

# Output the formatted JSON structure
cat <<EOF
{
  "Version": 1,
  "AccessKeyId": "$ACCESS_KEY_ID",
  "SecretAccessKey": "$SECRET_ACCESS_KEY"
}
EOF
