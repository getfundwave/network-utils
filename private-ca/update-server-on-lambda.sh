FUNCTION_NAME=${1:-'privateCA'}
REGION=${2:-'ap-south-1'}
PROFILE=${3:-'default'}

cd server
npm i
zip -r ./lambda.zip .
mv lambda.zip ../
cd ..

aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --zip-file fileb://lambda.zip --region $REGION --profile $PROFILE 1>/dev/null 2>/dev/stderr

rm -r lambda.zip