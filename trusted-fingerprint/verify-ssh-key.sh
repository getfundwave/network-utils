#!/bin/bash

HOST=$1
USER_KEY=$2
VERIFY_SSH_LAMBDA_URL=${3:-$VERIFY_SSH_LAMBDA_URL}
VERIFY_SSH_LAMBDA_TOKEN=${4:-$VERIFY_SSH_LAMBDA_TOKEN}
KNOWN_HOSTS=${5:-"/home/$USER/.ssh/known_hosts"}

USER_KEY_TYPE=$(echo $USER_KEY | cut -d " " -f 1)

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
if [[ $(grep -q "$HOST $USER_KEY_TYPE" "$KNOWN_HOSTS"; echo $?) -eq 0 || 
        $(grep -q "$hashed_hostname $USER_KEY_TYPE" "$KNOWN_HOSTS"; echo $?) -eq 0 
    ]]; then
    echo "Key found in known_hosts."
    exit 0
else
    echo "Key not found in known_hosts."
    echo "Attempting key verification..."

    lambda_response_status=$(curl -sw '%{http_code}' \
    -o key.txt \
    -X 'POST' \
    -H 'Content-Type: application/json' \
    -d '{
            "Host": '"\"${HOST}\""', 
            "KeyType": '"\"${USER_KEY_TYPE}\""', 
            "Authorization": '"\"Bearer ${VERIFY_SSH_LAMBDA_TOKEN}\""'
        }' \
    $VERIFY_SSH_LAMBDA_URL)

    if [[ $lambda_response_status != "200" ]]; then
        echo "Encountered server error"
        exit 1
    fi

    lambda_response_key=$(cat key.txt)
    rm key.txt

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