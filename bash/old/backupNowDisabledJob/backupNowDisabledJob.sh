#!/bin/bash

cluster='mycluster'
username='myusername'
password='mypassword'
domain='mydomain.net'
jobname='MyJob'
keeplocalfor=5

# authenticate
auth=$(curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/accessTokens" \
    -H 'Accept: application/json' \
    -H 'Content-type: application/json' -d '{
    "password": "'${password}'",
    "username": "'${username}'",
    "domain": "'${domain}'"
}' 2>/dev/null)

token=$(echo $auth | sed "s/.*\"accessToken\":\"\([^\"]*\).*/\1/")

# find job
job=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobs?names=${jobname}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" 2>/dev/null)
job="xxbeginxx${job}xxendxx"
job=$(echo $job | sed "s/xxbeginxx\[//g")
job=$(echo $job | sed "s/\]xxendxx//g")

jobid=$(echo $job | sed "s/.*\"id\":\([0-9]*\).*/\1/g")

# get last job run ID
run=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionRuns?jobId=${jobid}&numRuns=1"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" 2>/dev/null)

lastRunId=$(echo $run | sed "s/.*\"jobRunId\":\([0-9]*\).*/\1/g")
newRunId=$lastRunId

# enable job
enable=$(curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobState/${jobid}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" \
    -d '{"pause": false, "pauseReason": 0}' 2>/dev/null)
sleep 3

# run job
echo "running ${jobname} (${jobid})..."

curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobs/run/${jobid}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" \
    -d '{
            "runType": "kRegular",
            "copyRunTargets":[
                {
                    "type": "kLocal",
                    "daysToKeep": '${keeplocalfor}'
                }
            ]
        }'

# wait for new run to appear
while [ $newRunId -eq $lastRunId ]
do
run=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionRuns?jobId=${jobid}&numRuns=1"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" 2>/dev/null)

newRunId=$(echo $run | sed "s/.*\"jobRunId\":\([0-9]*\).*/\1/g")
sleep 1
done

# wait for job run to finish
status="kRunning"
finishedStates=(kCanceled kSuccess kFailure)
while [[ ! " ${finishedStates[@]} " =~ " ${status} " ]]
do
    sleep 1
    run=$(curl -X GET -k \
        --url "https://${cluster}/irisservices/api/v1/public/protectionRuns?jobId=${jobid}&numRuns=1"  \
        -H 'Content-type: application/json' \
        -H "authorization: Bearer ${token}" 2>/dev/null)
    status=$(echo $run | sed "s/.*\"status\":\"\([^\"]*\).*/\1/g")
done

echo "Status: $status"

# disable job
enable=$(curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobState/${jobid}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" \
    -d '{"pause": true, "pauseReason": 0}' 2>/dev/null)
