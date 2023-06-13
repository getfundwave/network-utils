# SSH Key Retrieval

This function, deployed as an AWS lambda function retrieves the SSH public key from a remote server using the Paramiko library. The function expects two parameters in the event payload: `url` and `keyType`. It establishes an SSH connection to the specified host using the provided URL and retrieves the public key using the specified key type.

## Dependencies

The function requires the Paramiko library to be installed. This can be included as a Lambda layer when creating the Lambda function.

## Usage

To set up as a Lambda function, follow these steps:

1. Create a new IAM role with `AWSLambdaBasicExecutionRole` policy.
2. Copy the Role ARN and set it as `VERIFY_SSH_LAMBDA_ROLE_ARN` environment variable (Alternatively, you can pass it as an input parameter to `deploy-lambda-layer.sh`). 
3. Run `deploy-lambda-layer.sh` to deploy the lambda function along with the layer.
4. To update the lambda function, edit `server.py` then run `update-lambda.sh`.
5. To update the layer, modify `requirements.txt` and then run `update-layer.sh`.
6. Configure an API via API Gateway as an event source to trigger the Lambda function with the required event payload.

To set up an API using API Gateway, follow these steps:

1. Click on `Add trigger` in lambda function homepage.
2. Select `API Gateway` as source.
3. Select `Create a new API` and choose `REST API`.
4. Select `API key` under security.
5. Go to the API's homepage and under `actions` select `Create Method` and create a `GET` method.
6. Choose `Integration type` as `Lambda Function` and add the name of the function in `Lambda function` field. Click on `Save`.
7. In the API homepage, click on `Method request`. Select `Validate query string parameters and headers` under `Request Validator` and set `API Key Required` to `true`.
8. Under `URL Query String Parameters` add parameters: `keyType` and `url`. Set them both to `Required`.
9. Go back to `Method Execution` and click on `Integration Request`.
10. Click on `Mapping Templates` and under `Request body passthrough` select `When there are no templates defined`.
11. Click on `Add mapping template` and enter `application/json` under `Content-Type`
12. Add the following template underneath it:
```
{
    "url":  "$input.params('url')",
    "keyType":  "$input.params('keyType')"
}
```
13. Click on `save`
14. Go back to `Method Execution` and click on `Test` to test the API.

To set up Github Actions Workflow, follow these steps:

1. Create a new role in IAM dashboard.
2. Select `Web Identity` under `Trusted entity type`.
3. Click on `Create new` under `Identity provider`.
4. Select `OpenID Connect` as `Provider type`.
5. For the `Provider URL`: Use `https://token.actions.githubusercontent.com`
6. For the `Audience`: Use `sts.amazonaws.com`.
7. Create a role with this identity provider.
8. Add the following policy to the role under permission policy:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "lambda:UpdateFunctionCode",
            "Resource": <ARN of the lambda function>
        }
    ]
}
```
9. Edit `Trusted entities` under `Trust Relationships` to add the `sub` field to the validation conditions. For example:
```
"Condition": {
    "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:getfundwave/production:ref:refs/heads/master"
    }
}
```
10. Add the following workflow secrets:
- `AWS_REGION` - The AWS region in which the lambda is created
- `AWS_SSH_UPDATE_ROLE_ARN`  - The ARN for the role created above

### Event Payload

The Lambda function expects the following parameters in the `event` object:

- `url` (string): The URL or IP address of the remote server to connect to.
- `keyType` (string): The type of SSH key to retrieve (e.g., "ssh-rsa", "ssh-ed25519", etc.).

### Return Value

The Lambda function returns a JSON object with the following properties:

- `statusCode` (integer): The HTTP status code of the response.
- `keyBody` (string): The base64-encoded string representation of the retrieved SSH public key. If an error occurs during the retrieval process, this property will be set to `null`. 