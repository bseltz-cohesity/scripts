#!/bin/bash

cluster='mycluster'
username='myusername'
password='mypassword'
domain='mydomain.net'
jobname='My Job'
keeplocalfor=5

auth=$(curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/accessTokens" \
    -H 'Accept: application/json' \
    -H 'Content-type: application/json' -d '{
    "password": "'${password}'",
    "username": "'${username}'",
    "domain": "'${domain}'"
}' 2>/dev/null)

token=$(echo $auth | sed "s/.*\"accessToken\":\"\([^\"]*\).*/\1/")

job=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobs?names=${jobname}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" 2>/dev/null)

jobid=$(echo $job | sed "s/.*\"id\":\([0-9]*\).*/\1/g")

echo "running ${jobname} (${jobid})..."

curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobs/run/${jobid}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" \
    -d '{"copyRunTargets":[],"runNowParameters":[],"runType":"kLog"}'
