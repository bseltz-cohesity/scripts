FROM alpine-cohesity-slim:latest

RUN apk add --no-cache postgresql13 \
  && apk add --no-cache s3cmd \
  && apk add --no-cache jq \
  && apk add --no-cache s-nail \
  && apk add --no-cache mongodb-tools \
  && rm -rf /var/cache/apk/*

COPY --chmod=0755 backup.sh /
COPY --chmod=0755 restore.sh /