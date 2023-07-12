FROM ubuntu:latest

ENV CA_ACTION=""
ENV CA_LAMBDA_URL=""
ENV USER_SSH_DIR=""
ENV SYSTEM_SSH_DIR=""
ENV SYSTEM_SSL_DIR=""
ENV AWS_STS_REGION=""
ENV AWS_PROFILE=""

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    openssl \
    openssh-client \
    jq

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN sudo ./aws/install

COPY . /app
WORKDIR /app

RUN chmod +x generate-certificate-curl.sh

ENTRYPOINT ["/bin/bash", "-c", "./generate-certificate.sh"] 

CMD [" ${CA_ACTION}" , "${CA_LAMBDA_URL}", "${USER_SSH_DIR}", "${SYSTEM_SSH_DIR}", "${SYSTEM_SSL_DIR}", "${AWS_STS_REGION}", "${AWS_PROFILE}"]

RUN sleep infinity