#!/bin/bash
read -p "Enter profile name > " PROFILE
read -p "Enter access key id > " ACCESS_KEY_ID
read -sp "Enter secret key >" SECRET_ACCESS_KEY

PROFILE=${PROFILE:-'default'}
password=$(echo "$ACCESS_KEY_ID":"$SECRET_ACCESS_KEY")
printf $password | secret-tool store --label="AWS Account Access Key-Pair $PROFILE" provider aws profile $PROFILE

printf "\nDone\n"

