#!/bin/bash

FUNCTION_NAME=${1:-'privateCA'}
REGION=${2:-'eu-central-1'}
PROFILE=${3:-''}

[[ -n "$PROFILE" ]] && PROFILE="--profile $PROFILE" || PROFILE=""

(cd server
npm i
npm run build
cd dist && zip -qr ../../lambda.zip .)

aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file fileb://lambda.zip \
    --region "$REGION" \
    $PROFILE

rm -r lambda.zip
