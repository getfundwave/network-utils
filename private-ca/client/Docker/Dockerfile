FROM ubuntu:20.04

ENV CA_ACTION=${CA_ACTION} \
    CA_LAMBDA_URL=${CA_LAMBDA_URL} \
    USER_SSH_DIR=${USER_SSH_DIR} \
    SYSTEM_SSH_DIR=${SYSTEM_SSH_DIR} \
    SYSTEM_SSL_DIR=${SYSTEM_SSL_DIR} \
    AWS_STS_REGION=${AWS_STS_REGION} \
    AWS_PROFILE=${AWS_PROFILE}

RUN DEBIAN_FRONTEND="noninteractive" apt-get update && apt-get install -y tzdata keyboard-configuration
RUN apt-get -y install curl unzip groff less jq pip python3 python3-venv openssh-client openssl
RUN pip install boto3

COPY . /app
WORKDIR /app

RUN chmod +x generate-certificate-curl.sh

ENTRYPOINT ["/bin/bash", "-c", "./generate-certificate-curl.sh", " ${CA_ACTION}" , "${CA_LAMBDA_URL}", "${USER_SSH_DIR}", "${SYSTEM_SSH_DIR}", "${SYSTEM_SSL_DIR}", "${AWS_STS_REGION}", "${AWS_PROFILE}"]