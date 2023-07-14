# SSH Key Retrieval

This function, deployed as an AWS lambda function retrieves the SSH public key from a remote server using the Paramiko library. The function expects three parameters in the event payload: `Host`, `KeyType` and `Authorization`. It establishes an SSH connection to the specified host using the provided URL and retrieves the public key using the specified key type.

## Dependencies

The function requires the Paramiko library to be installed. This can be included as a Lambda layer when creating the Lambda function.

## Usage

To set up as a Lambda function, follow these steps:

1. Create a new IAM role with `AWSLambdaBasicExecutionRole` policy.
2. Copy the Role ARN and set it as `VERIFY_SSH_LAMBDA_ROLE_ARN` environment variable (Alternatively, you can pass it as an input parameter to `deploy-lambda-layer.sh`). 
3. Run `deploy-lambda-layer.sh` to deploy the lambda function along with the layer.
4. To update the lambda function, edit `server.py` then run `update-lambda.sh`.
5. To update the layer, modify `requirements.txt` and then run `update-layer.sh`.
6. Add an environment variable called `SECRET_TOKEN` and set its value to a token to be used in Authorization header while invoking the lambda.
6. Configure an API via API Gateway as an event source to trigger the Lambda function with the required event payload.

To set up an API using API Gateway, follow these steps:

1. Click on `Add trigger` in lambda function homepage.
2. Select `API Gateway` as source.
3. Select `Create a new API` and choose `HTTP API`.
4. Select `Open` under security and click on `Add`.

To set up Github Actions Workflow, follow these steps:

1. Create a new role in IAM dashboard.
2. Select `Web Identity` under `Trusted entity type`.
3. Click on `Create new` under `Identity provider`.
4. Select `OpenID Connect` as `Provider type`.
5. For the `Provider URL`: Use `https://token.actions.githubusercontent.com`
6. For the `Audience`: Use `sts.amazonaws.com`.
7. Create a role with this identity provider.
8. Add the following policy to the role under permission policy:
```json
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
```json
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

- `Host` (string): The URL or IP address of the remote server to connect to.
- `KeyType` (string): The type of SSH key to retrieve (e.g., "ssh-rsa", "ssh-ed25519", etc.).
- `Authorization` (string): The authorization token with the form `Bearer <token>`.

### Usage Sample

```bash
curl -X 'POST' \
    -H 'Content-Type: application/json' \
    -d '{
            "Host": "ravenclaw.fundwave.com", 
            "KeyType": "ssh-rsa", 
            "Authorization": "Bearer <token>"
        }' \
    <lambda_url>
```

### Return Value

The Lambda function returns a JSON object with the following properties:

- `statusCode` (integer): The HTTP status code of the response.
- `body` (string): The base64-encoded string representation of the retrieved SSH public key (in case there are no errors).