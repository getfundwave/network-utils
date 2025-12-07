FROM node:22-alpine

RUN mkdir -p /home/node/test
RUN chown -R node:node /home/node/test

WORKDIR /home/node/test

COPY .npmrc /home/node/.npmrc
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER node

ENTRYPOINT ["sh", "/entrypoint.sh"]