#!/bin/bash

PROFILE=${1:-'default'}

if [ $(uname -o) == "GNU/Linux" ] 
then
  CREDENTIALS=$(secret-tool lookup provider aws profile $PROFILE)
elif [ $(uname -o) == "Darwin" ] 
then
  CREDENTIALS=$(security find-generic-password -s "AWS Account Access Key-Pair $PROFILE" -a "$PROFILE"  -w )
fi 

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