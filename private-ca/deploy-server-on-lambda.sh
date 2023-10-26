#!/bin/bash

SECRET_NAME=${1:-"privateCA"}
ROLE_NAME=${2:-"privateCALambdaRole"}
POLICY_NAME=${3:-"PrivateCAPolicy"}
LAYER_NAME=${4:-"openssh"}
FUNCTION_NAME=${5:-"privateCA"}
AWS_REGION=${6:-"ap-southeast-1"}
AWS_PROFILE=${7:-"default"}
################## Secret ##################

# Generate Keys
ssh-keygen -t rsa -b 4096 -f host_ca -C host_ca -N ""
ssh-keygen -t rsa -b 4096 -f user_ca -C user_ca -N ""

openssl genrsa -out key.pem 2048
openssl rsa -in key.pem -outform PEM -pubout -out public.pem
openssl req -new -x509 -key key.pem -out root.crt -days 365 -subj "/C=US/ST=California/L=YourCity/O=Fundwave/OU=Fundwave/CN=FundwaveCA"

HOST_CA_PRIVATE_KEY=$(cat host_ca | base64 | tr -d \\n)
HOST_CA_PUBLIC_KEY=$(cat host_ca.pub | base64 | tr -d \\n)
USER_CA_PRIVATE_KEY=$(cat user_ca | base64 | tr -d \\n)
USER_CA_PUBLIC_KEY=$(cat user_ca.pub | base64 | tr -d \\n)
ROOT_SSL_PRIVATE_KEY=$(cat key.pem | base64 | tr -d \\n)
ROOT_SSL_PUBLIC_KEY=$(cat public.pem | base64 | tr -d \\n)
ROOT_SSL_CERT=$(cat root.crt | base64 | tr -d \\n)

echo "{\"host_ca\": \"${HOST_CA_PRIVATE_KEY}\", \"host_ca.pub\": \"${HOST_CA_PUBLIC_KEY}\", \"user_ca\": \"${USER_CA_PRIVATE_KEY}\",\"user_ca.pub\": \"${USER_CA_PUBLIC_KEY}\",\"root_ssl_private_key\": \"${ROOT_SSL_PRIVATE_KEY}\",\"root_ssl_public_key\": \"${ROOT_SSL_PUBLIC_KEY}\", \"rootX509cert\": \"${ROOT_SSL_CERT}\"}" | jq . > secret.json

# Create Secret
SECRET_ARN=$(aws secretsmanager create-secret \
    --name $SECRET_NAME \
    --secret-string file://secret.json \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
     | jq ".ARN" | tr -d '"')

# Clean up
rm host_ca host_ca.pub user_ca user_ca.pub key.pem public.pem root.crt secret.json
############################################

################### Role ###################

# Create role for lambda
echo "{\"Version\": \"2012-10-17\",\"Statement\": [{\"Sid\": \"AllowLambdaAssumeRole\",\"Effect\": \"Allow\",\"Principal\": {\"Service\": \"lambda.amazonaws.com\"},\"Action\": \"sts:AssumeRole\"}]}" | jq . > Trust-Policy.json

ROLE_ARN=$(aws iam create-role \
    --role-name  $ROLE_NAME \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --assume-role-policy-document file://Trust-Policy.json | jq ".Role.Arn" | tr -d '"')

# Create Policy for Lambda Role to Read and Update Secrets
echo "{\"Version\": \"2012-10-17\",\"Statement\": [{\"Sid\": \"VisualEditor0\",\"Effect\": \"Allow\",\"Action\": [\"secretsmanager:GetSecretValue\"],\"Resource\": \"${SECRET_ARN}\"}, {\"Action\": [\"logs:CreateLogGroup\",\"logs:CreateLogStream\",\"logs:PutLogEvents\"],\"Effect\": \"Allow\",\"Resource\": \"arn:aws:logs:*:*:*\"}]}" | jq . > Policy.json

POLICY_ARN=$(aws iam create-policy --policy-name $POLICY_NAME --region $AWS_REGION --profile $AWS_PROFILE --policy-document file://Policy.json | jq ".Policy.Arn" | tr -d '"')

# Attach policy to role
aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN --region $AWS_REGION --profile $AWS_PROFILE

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
    --profile $AWS_PROFILE \
    --query 'LayerVersionArn' \
    --output text)
cd ..

# Clean up
sudo rm -r openssh-layer/ 
############################################

################## Lambda ##################

# Create lambda function
cd server
npm i
zip -r ./lambda.zip .
mv lambda.zip ../
cd ..

aws lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime nodejs18.x \
  --region $AWS_REGION \
  --profile $AWS_PROFILE \
  --handler index_lambda.handler \
  --zip-file fileb://lambda.zip \
  --layers $LAYER_ARN \
  --role $ROLE_ARN

aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type "NONE" \
    --statement-id url \
    --region $AWS_REGION \
    --profile $AWS_PROFILE

FUNCTION_URL=$(aws lambda create-function-url-config --function-name "privateCA" --auth-type "NONE" --region $AWS_REGION --profile $AWS_PROFILE | jq -r ".FunctionUrl")

echo "CA deployed at URL:"
echo "${FUNCTION_URL}"

# Clean up
rm -r server/node_modules/ server/package-lock.json lambda.zip 
###########################################