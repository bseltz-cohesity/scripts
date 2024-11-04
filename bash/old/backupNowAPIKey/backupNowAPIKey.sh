#!/bin/bash

# version 2020.06.04

cluster='mycluster'
apikey='12345678-1234-5678-9012-345678901234'
jobname='my job'
replicateto='anothercluster'
keepreplicafor=5
archiveto='S3'
keeparchivefor=5
keeplocalfor=15

remote=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/remoteClusters?names=${replicateto}"  \
    -H 'Content-type: application/json' \
    -H "apiKey: ${apikey}" 2>/dev/null)

remotename=$(echo $remote | sed "s/.*\"name\"\:\"\([^\"]*\).*/\1/g")
remoteid=$(echo $remote | sed "s/.*\"clusterId\":\([0-9]*\).*/\1/g")

echo "replicating to ${remotename} (${remoteid})"

vault=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/vaults?name=${archiveto}"  \
    -H 'Content-type: application/json' \
    -H "apiKey: ${apikey}" 2>/dev/null)

vaultname=$(echo $vault | sed "s/.*\"name\"\:\"\([^\"]*\).*/\1/g")
vaultid=$(echo $vault | sed "s/.*\"id\":\([0-9]*\).*/\1/g")

echo "archiving to ${vaultname} (${vaultid})"

job=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobs?names=${jobname}"  \
    -H 'Content-type: application/json' \
    -H "apiKey: ${apikey}" 2>/dev/null)

jobid=$(echo $job | sed "s/.*\"id\":\([0-9]*\).*/\1/g")

echo "running ${jobname} (${jobid})..."

curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobs/run/${jobid}"  \
    -H 'Content-type: application/json' \
    -H "apiKey: ${apikey}" \
    -d '{
    "runType": "kRegular",
    "copyRunTargets":[
        {
            "type": "kLocal",
            "daysToKeep": '${keeplocalfor}'
        },
        {
            "type": "kRemote",
            "daysToKeep": '${keepreplicafor}',
            "replicationTarget": {
                "clusterId": '${remoteid}',
                "clusterName": "'${remotename}'"
            }
        },
        {
            "archivalTarget": {
                "vaultId": '${vaultid}',
                "vaultName": "'${vaultname}'",
                "vaultType": "kCloud"
            },
            "daysToKeep": '${keeparchivefor}',
            "type": "kArchival"
        }
    ]
}'