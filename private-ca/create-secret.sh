#!/bin/bash

SECRET_NAME=${1:-"privateCASecret"}

# Generate Keys
ssh-keygen -t rsa -b 4096 -f host_ca -C host_ca -N ""
ssh-keygen -t rsa -b 4096 -f user_ca -C user_ca -N ""

openssl genrsa -out key.pem 2048
openssl rsa -in key.pem -outform PEM -pubout -out public.pem

HOST_CA_PRIVATE_KEY=$(cat host_ca | base64 -w 0)
HOST_CA_PUBLIC_KEY=$(cat host_ca.pub | base64 -w 0)
USER_CA_PRIVATE_KEY=$(cat user_ca | base64 -w 0)
USER_CA_PUBLIC_KEY=$(cat user_ca.pub | base64 -w 0)
ROOT_SSL_PRIVATE_KEY=$(cat key.pem | base64 -w 0)
ROOT_SSL_PUBLIC_KEY=$(cat public.pem | base64 -w 0)

echo "{\"host_ca\": \"${HOST_CA_PRIVATE_KEY}\", \"host_ca.pub\": \"${HOST_CA_PUBLIC_KEY}\", \"user_ca\": \"${USER_CA_PRIVATE_KEY}\",\"user_ca.pub\": \"${USER_CA_PUBLIC_KEY}\",\"root_ssl_private_key\": \"${ROOT_SSL_PRIVATE_KEY}\",\"root_ssl_public_key\": \"${ROOT_SSL_PUBLIC_KEY}\"}" | jq . > secret.json

# Create Secret
SECRET_ARN=$(aws secretsmanager create-secret \
    --name $SECRET_NAME \
    --secret-string file://secret.json | jq ".ARN" | tr -d '"')

echo SECRET_ARN

# Clean up
rm host_ca user_ca *.pub *.pem *.json