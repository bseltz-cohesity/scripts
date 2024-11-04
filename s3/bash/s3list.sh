#!/bin/bash
date=`date +%Y%m%d`
dateFormatted=`date -R`
s3Bucket="myview"
relativePath="/${s3Bucket}"
contentType="text/plain"
stringToSign="GET\n\n${contentType}\n${dateFormatted}\n${relativePath}"
s3AccessKey="soz8UmIsN8hLHNfmf0gr8M-cIuDlcdRf3jA3bkphkEA"
s3SecretKey="3gnUMvsp8nxYLPUWneH5v8L3TRZ3vQDt3pb3lblzS-g"
signature=`echo -en ${stringToSign} | openssl sha1 -hmac ${s3SecretKey} -binary | base64`
curl -k -X GET \
-H "Host: mycluster" \
-H "Date: ${dateFormatted}" \
-H "Content-Type: ${contentType}" \
-H "Authorization: AWS ${s3AccessKey}:${signature}" \
https://mycluster:3000/${s3Bucket}
