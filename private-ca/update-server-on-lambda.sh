FUNCTION_NAME=${1:-'privateCA'}
REGION=${2:-'ap-southeast-1'}
PROFILE=${3:-'default'}

cd server
npm i
zip -qr ./lambda.zip .
mv lambda.zip ../
cd ..

aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --zip-file fileb://lambda.zip --region $REGION --profile $PROFILE >/dev/null 2>&1

rm -r lambda.zip