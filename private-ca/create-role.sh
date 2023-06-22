#!/bin/bash

SECRET_ARN=$1
ROLE_NAME=${2:-"privateCALambdaRole"}
POLICY_NAME=${3:-"AccessPrivateCASecretsPolicy"}

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

rm *.json