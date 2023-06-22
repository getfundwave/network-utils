#!/bin/bash

LAYER_NAME=${1:-"openssh"}

echo $LAYER_NAME

# Create OpenSSH layer
docker run --rm -v $(pwd)/openssh-layer:/lambda/opt lambci/yumda:2 yum install -y openssh
cd openssh-layer
echo "**************************************************************************************************************************************************************************************************************************************************************************************************************"
echo $LAYER_NAME
zip -yr ./openssh-layer.zip . > /dev/null
LAYER_ARN=$(aws lambda publish-layer-version \
    --layer-name $LAYER_NAME \
    --zip-file fileb://openssh-layer.zip \
    --query 'LayerVersionArn' \
    --output text)
echo $LAYER_ARN
cd ..

rm -r openssh-layer/ *.zip