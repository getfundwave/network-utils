#!/bin/bash

# Variables
FUNCTION_NAME=${1:-"VerifySSHKey"}
AWS_REGION=${2:-"ap-south-1"}
AWS_PROFILE=${3:-"default"}
ZIP_FILE="lambda-function.zip"

# Package the updated Lambda function code
zip -r9 $ZIP_FILE server.py

# Update the Lambda function code
aws lambda update-function-code \
  --function-name $FUNCTION_NAME \
  --zip-file fileb://$ZIP_FILE \
  --region "${AWS_REGION}" \
  --profile "${AWS_PROFILE}"

# Clean up
rm $ZIP_FILE
