#!/bin/bash

# Variables
LAYER_NAME=${1:-"paramiko-layer"}
FUNCTION_NAME=${2:-"VerifySSHKey"}
AWS_REGION=${3:-"ap-south-1"}
AWS_PROFILE=${4:-"default"}
ZIP_FILE="layer.zip"

# Create a virtual environment and install dependencies
python3.8 -m venv env
source env/bin/activate

docker run -v "$PWD":/var/task "public.ecr.aws/sam/build-python3.8" /bin/sh -c "pip install --platform manylinux2010_x86_64 --implementation cp --python 3.8 --only-binary=:all: --upgrade -r requirements.txt -t python/lib/python3.8/site-packages; exit"

# Package the updated layer code
zip -r9 $ZIP_FILE python

# Publish a new version of the Lambda layer
LAYER_ARN=$(aws lambda publish-layer-version \
  --layer-name $LAYER_NAME \
  --description "My Layer" \
  --compatible-runtimes python3.8 \
  --zip-file fileb://$ZIP_FILE \
  --query 'LayerVersionArn' \
  --output text\
  --region "${AWS_REGION}" \
  --profile "${AWS_PROFILE}")

# Update the Lambda function(s) that use the layer
aws lambda update-function-configuration \
  --function-name $FUNCTION_NAME \
  --layers $LAYER_ARN \
  --region "${AWS_REGION}" \
  --profile "${AWS_PROFILE}"

# Clean up
rm -r env python
rm $ZIP_FILE
