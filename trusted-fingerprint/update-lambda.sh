#!/bin/bash

# Variables
FUNCTION_NAME=${1:-"VerifySSHKey"}
ZIP_FILE="lambda-function.zip"

# Package the updated Lambda function code
zip -r9 $ZIP_FILE server.py

# Update the Lambda function code
aws lambda update-function-code \
  --function-name $FUNCTION_NAME \
  --zip-file fileb://$ZIP_FILE

# Clean up
rm $ZIP_FILE
