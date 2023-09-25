FROM alpine:latest

ENV CA_ACTION=${CA_ACTION} \
    CA_LAMBDA_URL=${CA_LAMBDA_URL} \
    USER_SSH_DIR=${USER_SSH_DIR} \
    SYSTEM_SSH_DIR=${SYSTEM_SSH_DIR} \
    SYSTEM_SSL_DIR=${SYSTEM_SSL_DIR} \
    AWS_STS_REGION=${AWS_STS_REGION} \
    AWS_PROFILE=${AWS_PROFILE}

# RUN DEBIAN_FRONTEND="noninteractive" apt update && apt install -y tzdata keyboard-configuration
# RUN apt -y install curl unzip groff less jq pip python3 python3-venv openssh-client openssl cron
# RUN pip install boto3
RUN apk add bash curl unzip groff jq python3 openssh openssl
RUN python3 -m ensurepip
RUN pip3 install boto3

COPY . /app
WORKDIR /app

RUN chmod +x generate-certificate-curl.sh
RUN chmod +x run.sh
ENTRYPOINT ["/app/run.sh" ]
