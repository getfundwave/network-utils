#!/bin/bash
echo "0 0 */1 * * generate-certificate-curl.sh ${CA_ACTION} ${CA_LAMBDA_URL} ${USER_SSH_DIR} ${SYSTEM_SSH_DIR} ${SYSTEM_SSL_DIR} ${AWS_STS_REGION} ${AWS_PROFILE} > /dev/stdout" > crontab.txt
/usr/bin/crontab crontab.txt
/usr/sbin/crond -f -l 8
