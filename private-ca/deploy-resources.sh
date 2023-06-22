#!/bin/bash

SECRET_NAME=${1:-"privateCASecret"}
ROLE_NAME=${2:-"privateCALambdaRole"}
POLICY_NAME=${3:-"AccessPrivateCASecretsPolicy"}
LAYER_NAME=${4:-"openssh"}
FUNCTION_NAME=${5:-"privateCA"}

################## Secret ##################

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


############################################

################### Role ###################
# Create role for lambda
echo "{\"Version\": \"2012-10-17\",\"Statement\": [{\"Sid\": \"AllowLambdaAssumeRole\",\"Effect\": \"Allow\",\"Principal\": {\"Service\": \"lambda.amazonaws.com\"},\"Action\": \"sts:AssumeRole\"}]}" | jq . > Trust-Policy.json

ROLE_ARN=$(aws iam create-role \
    --role-name  $ROLE_NAME\
    --assume-role-policy-document file://Trust-Policy.json | jq ".Role.Arn" | tr -d '"')

# Create Policy for Lambda Role to Read and Update Secrets
echo "{\"Version\": \"2012-10-17\",\"Statement\": [{\"Sid\": \"VisualEditor0\",\"Effect\": \"Allow\",\"Action\": [\"secretsmanager:GetSecretValue\",\"secretsmanager:UpdateSecret\"],\"Resource\": \"${SECRET_ARN}\"}]}" | jq . > Policy.json

POLICY_ARN=$(aws iam create-policy --policy-name $POLICY_NAME --policy-document file://Policy.json | jq ".Policy.Arn" | tr -d '"')

# Attach policy to role
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN

############################################

################### Layer ##################

# Create OpenSSH layer
sudo docker run --rm -v $(pwd)/openssh-layer:/lambda/opt lambci/yumda:2 yum install -y openssh
cd openssh-layer
sudo zip -yr ./openssh-layer.zip . > /dev/null
LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name $LAYER_NAME \
    --zip-file fileb://openssh-layer.zip \
    --query 'LayerVersionArn' \
    --output text)
cd ..

############################################

################## Lambda ##################

# Create lambda function
cd lambda
npm i
zip -r ./lambda.zip .
mv lambda.zip ../
cd ..

aws lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime nodejs18.x \
  --handler index.handler \
  --zip-file fileb://lambda.zip \
  --layers $LAYER_ARN \
  --role $ROLE_ARN

###########################################

# Clean up
sudo rm -r openssh-layer/ host_ca user_ca *.pub *.pem *.json *.zip