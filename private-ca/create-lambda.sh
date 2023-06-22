#!/bin/bash

ROLE_ARN=$1
LAYER_ARN=$2
FUNCTION_NAME=${3:-"privateCA"}

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

# Clean up
rm *.zip