#!/bin/bash

# Variables
FUNCTION_NAME=${1:-"VerifySSHKey"}
LAYER_NAME=${2:-"paramiko-layer"}
VERIFY_SSH_LAMBDA_ROLE_ARN=${3:-$VERIFY_SSH_LAMBDA_ROLE_ARN}

LAMBDA_FUNCTION_ZIP_FILE="lambda-function.zip"
LAYER_ZIP_FILE="layer.zip"

# Create a virtual environment and install dependencies
mkdir -p python/lib/python3.8/site-packages

# As Paramiko has system level dependencies, we must package them in the same environment that lambda uses.
# Here we use the AWS Serverless Application Model (SAM) image to emulate the python3.8 AWS Lambda runtime.
# https://gallery.ecr.aws/sam/build-python3.8
docker run -v "$PWD":/var/task "public.ecr.aws/sam/build-python3.8" /bin/sh -c "python3.8 -m venv env && source env/bin/activate && pip install --platform manylinux2010_x86_64 --implementation cp --python 3.8 --only-binary=:all: --upgrade -r requirements.txt -t python/lib/python3.8/site-packages; exit"

# Package the Lambda function and the Paramiko layer
zip -r9 $LAMBDA_FUNCTION_ZIP_FILE server.py
zip -r9 $LAYER_ZIP_FILE python

# Create the Lambda layer
LAYER_ARN=$(aws lambda publish-layer-version \
  --layer-name $LAYER_NAME \
  --description "Layer for Paramiko" \
  --compatible-runtimes python3.8 \
  --zip-file fileb://$LAYER_ZIP_FILE \
  --query 'LayerVersionArn' \
  --output text)

# Create the Lambda function
aws lambda create-function \
  --function-name $FUNCTION_NAME \
  --runtime python3.8 \
  --handler server.lambda_handler \
  --zip-file fileb://$LAMBDA_FUNCTION_ZIP_FILE \
  --layers $LAYER_ARN \
  --role $VERIFY_SSH_LAMBDA_ROLE_ARN

# Clean up
sudo rm -r env python
sudo rm *.zip
docker rmi -f public.ecr.aws/sam/build-python3.8