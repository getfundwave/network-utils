#!/bin/bash
read -p "Enter profile name > " PROFILE
read -p "Enter access key id > " ACCESS_KEY_ID
read -sp "Enter secret key >" SECRET_ACCESS_KEY

password=$(echo "{ "AccessKeyId": "$ACCESS_KEY_ID", "SecretAccessKey": "$SECRET_ACCESS_KEY" }" | base64)
security add-generic-password -s "aws" -a $PROFILE -w $password