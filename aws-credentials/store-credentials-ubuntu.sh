#!/bin/bash
access_key_id=$1
secret_access_key_id=$2
profile=${3:-'internal'}

password=$(echo "{ "AccessKeyId": "$access_key_id", "SecretAccessKey": "$secret_access_key_id" }" | base64)
printf $password | secret-tool store --label="AWS Account Access Key-Pair" provider aws profile $profile