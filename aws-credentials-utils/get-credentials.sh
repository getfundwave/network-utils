#!/bin/bash

PROFILE=${1:-'default'}
OPTION=$2

if [ $(uname -o) == "GNU/Linux" ]
then
  CREDENTIALS=$(secret-tool lookup provider aws profile $PROFILE)
elif [ $(uname -o) == "Darwin" ]
then
  CREDENTIALS=$(security find-generic-password -s "AWS Account Access Key-Pair $PROFILE" -a "$PROFILE"  -w )
fi

ACCESS_KEY_ID=$(echo "$CREDENTIALS" | awk -F':' '{ print $1 }' )
SECRET_ACCESS_KEY=$(echo "$CREDENTIALS" | awk -F':' '{ print $2 }')
SESSION_TOKEN=$(echo "$CREDENTIALS" | awk -F':' '{ print $3 }')

# Output the formatted JSON structure
if [ "$OPTION" != "notoken" ]; then
  cat <<EOF
  {
    "Version": 1,
      "AccessKeyId": "$ACCESS_KEY_ID",
      "SecretAccessKey": "$SECRET_ACCESS_KEY",
      "SessionToken": "$SESSION_TOKEN"
  }
EOF
else

  cat <<EOF
  {
    "Version": 1,
      "AccessKeyId": "$ACCESS_KEY_ID",
      "SecretAccessKey": "$SECRET_ACCESS_KEY"
  }
EOF
fi
