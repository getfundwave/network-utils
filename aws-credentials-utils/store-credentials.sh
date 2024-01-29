#!/bin/bash

PROFILE=${1:-'default'}

read -p "Enter profile name > " PROFILE
read -p "Enter access key id > " ACCESS_KEY_ID
read -sp "Enter secret key >" SECRET_ACCESS_KEY

CREDENTIALS=$(echo "$ACCESS_KEY_ID":"$SECRET_ACCESS_KEY")

if [ $(uname -o) == "GNU/Linux" ] 
then
    printf $CREDENTIALS | secret-tool store --label="AWS Account Access Key-Pair $PROFILE" provider aws profile "creds$PROFILE"
elif [ $(uname -o) == "Darwin" ] 
then
    security add-generic-password -s "AWS Account Access Key-Pair $PROFILE" -a $PROFILE -w $CREDENTIALS
fi 

printf "\nDone\n"

