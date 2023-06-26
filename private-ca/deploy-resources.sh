#!/bin/bash

SECRET_NAME=${1:-"privateCASecret"}
ROLE_NAME=${2:-"privateCALambdaRole"}
POLICY_NAME=${3:-"AccessPrivateCASecretsPolicy"}
LAYER_NAME=${4:-"openssh"}
FUNCTION_NAME=${5:-"privateCA"}
AWS_REGION=${6:-"ap-south-1"}

################## Secret ##################

# Generate Keys
ssh-keygen -t rsa -b 4096 -f host_ca -C host_ca -N ""
ssh-keygen -t rsa -b 4096 -f user_ca -C user_ca -N ""

openssl genrsa -out key.pem 2048
openssl rsa -in key.pem -outform PEM -pubout -out public.PEM
openssl req -new -x509 -key key.pem -out root.crt -days 365 -subj "/C=US/ST=California/L=YourCity/O=Fundwave/OU=Fundwave/CN=FundwaveCA"

HOST_CA_PRIVATE_KEY=$(cat host_ca | base64 -w 0)
HOST_CA_PUBLIC_KEY=$(cat host_ca.pub | base64 -w 0)
USER_CA_PRIVATE_KEY=$(cat user_ca | base64 -w 0)
USER_CA_PUBLIC_KEY=$(cat user_ca.pub | base64 -w 0)
ROOT_SSL_PRIVATE_KEY=$(cat key.pem | base64 -w 0)
ROOT_SSL_PUBLIC_KEY=$(cat public.pem | base64 -w 0)
ROOT_SSL_CERT=$(cat root.pem | base64 -w 0)

echo "{\"host_ca\": \"${HOST_CA_PRIVATE_KEY}\", \"host_ca.pub\": \"${HOST_CA_PUBLIC_KEY}\", \"user_ca\": \"${USER_CA_PRIVATE_KEY}\",\"user_ca.pub\": \"${USER_CA_PUBLIC_KEY}\",\"root_ssl_private_key\": \"${ROOT_SSL_PRIVATE_KEY}\",\"root_ssl_public_key\": \"${ROOT_SSL_PUBLIC_KEY}\", \"rootX509cert\": \"${ROOT_SSL_CERT}\"}" | jq . > secret.json

# Create Secret
SECRET_ARN=$(aws secretsmanager create-secret \
    --name $SECRET_NAME \
    --secret-string file://secret.json \
    --region $AWS_REGION | jq ".ARN" | tr -d '"')

# Clean up
rm host_ca host_ca.pub user_ca user_ca.pub key.pem public.pem root.pem root.crt
############################################

################### Role ###################
# Create role for lambda
echo "{\"Version\": \"2012-10-17\",\"Statement\": [{\"Sid\": \"AllowLambdaAssumeRole\",\"Effect\": \"Allow\",\"Principal\": {\"Service\": \"lambda.amazonaws.com\"},\"Action\": \"sts:AssumeRole\"}]}" | jq . > Trust-Policy.json

ROLE_ARN=$(aws iam create-role \
    --role-name  $ROLE_NAME \
    --region $AWS_REGION \
    --assume-role-policy-document file://Trust-Policy.json | jq ".Role.Arn" | tr -d '"')

# Create Policy for Lambda Role to Read and Update Secrets
echo "{\"Version\": \"2012-10-17\",\"Statement\": [{\"Sid\": \"VisualEditor0\",\"Effect\": \"Allow\",\"Action\": [\"secretsmanager:GetSecretValue\",\"secretsmanager:UpdateSecret\"],\"Resource\": \"${SECRET_ARN}\"}]}" | jq . > Policy.json

POLICY_ARN=$(aws iam create-policy --policy-name $POLICY_NAME --region $AWS_REGION --policy-document file://Policy.json | jq ".Policy.Arn" | tr -d '"')

# Attach policy to role
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN --region $AWS_REGION

# Clean up
rm Trust-Policy.json Policy.json
############################################

################### Layer ##################

# Create OpenSSH layer
sudo docker run --rm -v $(pwd)/openssh-layer:/lambda/opt lambci/yumda:2 yum install -y openssh
cd openssh-layer
sudo zip -yr ./openssh-layer.zip . > /dev/null
LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name $LAYER_NAME \
    --zip-file fileb://openssh-layer.zip \
    --region $AWS_REGION \
    --query 'LayerVersionArn' \
    --output text)
cd ..

# Clean up
sudo rm -r openssh-layer/ 
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
  --region $AWS_REGION \
  --handler index.handler \
  --zip-file fileb://lambda.zip \
  --layers $LAYER_ARN \
  --role $ROLE_ARN

# Clean up
rm lambda.zip
###########################################
