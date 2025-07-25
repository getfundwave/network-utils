FROM alpine:3.18.3

RUN apk add bash curl jq python3 openssh

WORKDIR /app

COPY invoke-private-ca.sh .
COPY aws-auth-header.py .

RUN chmod +x invoke-private-ca.sh

ENTRYPOINT ["bash", "invoke-private-ca.sh"]