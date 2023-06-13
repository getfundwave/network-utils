#!/bin/bash

HOST=$1
USER_KEY=$2
VERIFY_SSH_LAMBDA_URL=${3:-$VERIFY_SSH_LAMBDA_URL}
VERIFY_SSH_LAMBDA_API_KEY=${4:-$VERIFY_SSH_LAMBDA_API_KEY}

USER_KEY_TYPE=$(echo $USER_KEY | cut -d " " -f 1)
KNOWN_HOSTS="/home/$USER/.ssh/known_hosts"

if [[ $USER_KEY_TYPE == "ssh-ed25519" ]]; then
    host_key=$(ssh-keyscan -t ed25519 $HOST | awk '{print $3}')
elif [[ $USER_KEY_TYPE == "ssh-rsa" ]]; then
    host_key=$(ssh-keyscan -t rsa $HOST | awk '{print $3}')
elif [[ $USER_KEY_TYPE == "ecdsa-sha2-nistp256" ]]; then
    host_key=$(ssh-keyscan -t ecdsa $HOST | awk '{print $3}')
fi

# Check if the key is empty
if [[ -z "$host_key" ]]; then
    echo "The corresponding $USER_KEY_TYPE key could not be found on the host"
    exit 1
fi

hashed_hostname=$(echo -n "$HOST" | sha256sum | cut -d " " -f 1 | awk '{ print $1 }')

# Check if the hostname (hashed or unhashed) exists in known hosts
if [[ $(grep -q "$HOST" "$KNOWN_HOSTS"; echo $?) -eq 0 || $(grep -q "$hashed_hostname" "$KNOWN_HOSTS"; echo $?) -eq 0 ]]; then
    echo "Key found in known_hosts."
    exit 0
else
    echo "Key not found in known_hosts."
    echo "Attempting key verification..."

    lambda_response=$(curl --location --request GET "$VERIFY_SSH_LAMBDA_URL?url=$HOST&keyType=$USER_KEY_TYPE" --header "x-api-key: $VERIFY_SSH_LAMBDA_API_KEY"| awk '{print}')
    lambda_response_status=$(echo $lambda_response | cut -d " " -f 2 | cut -d '"' -f 2 | cut -d '}' -f 1| cut -d ',' -f 1)
    lambda_response_key=$(echo $lambda_response | cut -d " " -f 4 | cut -d '"' -f 2 | cut -d '}' -f 1)

    echo $lambda_response_status

    if [[ $lambda_response_status != "200" ]]; then
        echo "Encountered server error"
        exit 1
    fi

    if [[ 
        $host_key == $lambda_response_key
    ]]; then
        
        echo "Key verified."
        echo "Adding keys to known hosts"
        echo "$HOST $USER_KEY_TYPE $lambda_response_key" >> $KNOWN_HOSTS
        exit 0

    else
        echo "Key could not be verified"
        echo "Host Key ($host_key) does not match with lambda response ($lambda_response_key)"
        exit 1
    fi

fi