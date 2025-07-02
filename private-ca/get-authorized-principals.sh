#!/bin/bash

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

ENV_TAG=$(aws ec2 describe-tags \
  --region "$REGION" \
  --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=ENV" \
  --query "Tags[0].Value" \
  --output text)

echo $ENV_TAG