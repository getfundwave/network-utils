#!/bin/bash

CA_URL=${1:-$CA_URL}
AWS_PROFILE=${2:-"default"}
USER_SSH_DIR=${3:-"$HOME/.ssh"}
USER_AWS_DIR=${4:-"$HOME/.aws"}
AWS_STS_REGION=${5:-"ap-southeast-1"}

PYTHON_EXEC=$(which python 2>/dev/null || which python3 2>/dev/null)
[[ $? -ne 0 ]] && { echo "Python binary not found."; exit 1; }


is_mfa_enabled() {
  grep -q 'get-credentials' ${USER_AWS_DIR}/credentials
}

get_aws_credentials() {
    local TEMP_CREDS

    if is_mfa_enabled; then
        CALLER_IDENTITY=$(aws sts get-caller-identity --profile $AWS_PROFILE)
        [[ $? -ne 0 ]] && { echo "Your AWS credentials have either expired or are invalid. Please check your credentials and try again."; exit 1; }

        TEMP_CREDS=$(get-credentials $AWS_PROFILE)
    else
        #check if AWS creds are exposed as env variables, including AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN
        if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" && -n "$AWS_SESSION_TOKEN" ]]; then
            CALLER_IDENTITY=$(aws sts get-caller-identity)
            [[ $? -ne 0 ]] && { echo "Your AWS credentials have either expired or are invalid. Please check your credentials and try again."; exit 1; }
            TEMP_CREDS=$(echo "{\"AccessKeyId\":\"$AWS_ACCESS_KEY_ID\",\"SecretAccessKey\":\"$AWS_SECRET_ACCESS_KEY\",\"Token\":\"$AWS_SESSION_TOKEN\"}")
        else
            TEMP_CREDS=$(aws sts get-session-token --profile $AWS_PROFILE | jq -r ".Credentials")
        fi
    fi

    ACCESS_KEY_ID=$(echo $TEMP_CREDS | jq -r ".AccessKeyId")
    SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | jq -r ".SecretAccessKey")
    SESSION_TOKEN=$(echo $TEMP_CREDS | jq -r ".Token // .SessionToken // .Sessiontoken")
}

get_aws_credentials $ENVIRONMENT

if [ ! -d "private-ca-client-env" ]; then
  $PYTHON_EXEC -m venv private-ca-client-env
fi
source private-ca-client-env/bin/activate
pip install -q --upgrade --disable-pip-version-check boto3

# Update PYTHON_EXEC to use the Python executable from the activated virtual environment
# This ensures we use the venv's Python with the installed dependencies (boto3)
PYTHON_EXEC=$(which python 2>/dev/null || which python3 2>/dev/null)

# Auth Headers
output=$($PYTHON_EXEC aws-auth-header.py $ACCESS_KEY_ID $SECRET_ACCESS_KEY $SESSION_TOKEN $AWS_STS_REGION) || {
    echo "Failed to generate auth header. Check aws-auth-header.py script.";
    exit 1;
}
auth_header=$(echo "$output" | jq -er ".Authorization") || {
    echo "Failed to parse Authorization from auth-header output.";
    exit 1;
}
date=$(echo "$output" | jq -er ".Date") || {
    echo "Failed to parse Date from auth-header output.";
    exit 1;
}

EVENT_JSON=$(echo "{\"auth\":{\"amzDate\":\"${date}\",\"authorizationHeader\":\"${auth_header}\",\"sessionToken\":\"${SESSION_TOKEN}\"}, \"action\":\"getHostCAPublicKey\", \"awsSTSRegion\":\"${AWS_STS_REGION}\"}")

read -r STATUS_CODE LAMBDA_RESPONSE < <(
    curl -s "${CA_URL}" -H 'content-type: application/json' -d "$EVENT_JSON" -w "%{http_code}\n" | 
    {
        response=$(cat)
        status_code=${response: -3}
        body=${response:0:$((${#response}-3))}
        echo "$status_code $body"
    }
)

if [[ "$STATUS_CODE" != "200" ]]; then
    echo "CA request failed (Status: ${STATUS_CODE}): ${LAMBDA_RESPONSE}"
    exit 1;
fi

HOST_CA_PUBKEY=$(echo $LAMBDA_RESPONSE | jq -r ".\"host_ca.pub\"" | base64 -d)

[[ -f "${USER_SSH_DIR}/known_hosts" ]] || touch "${USER_SSH_DIR}/known_hosts"

# Add host CA public key to known_hosts file if it doesn't exist
if [[ $(grep -q "@cert-authority" "${USER_SSH_DIR}/known_hosts"; echo $?) -ne 0 ]]; then
    # @cert-authority tells ssh to trust the host CA public key
    # * means all hosts (wildcard) (you can also specify a list of comma separated hostnames)
    # ${HOST_CA_PUBKEY} is the host CA public key that was used to sign the host certificate
    echo "@cert-authority * ${HOST_CA_PUBKEY}" >> ${USER_SSH_DIR}/known_hosts
fi

deactivate