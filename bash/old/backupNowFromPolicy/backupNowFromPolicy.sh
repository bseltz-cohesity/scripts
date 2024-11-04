#!/bin/bash

cluster='mycluster'
username='myusername'
password='mypassword'
domain='mydomain.net'
jobname='My Job'

auth=$(curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/accessTokens" \
    -H 'Accept: application/json' \
    -H 'Content-type: application/json' -d '{
    "password": "'${password}'",
    "username": "'${username}'",
    "domain": "'${domain}'"
}' 2>/dev/null)

token=$(echo $auth | sed "s/{.*\"accessToken\":\"\([^\"]*\).*}/\1/g")

job=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobs?names=${jobname}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" 2>/dev/null)

jobid=$(echo $job | sed "s/.*\"id\":\([0-9]*\).*/\1/g")

echo "running ${jobname} (${jobid})..."

policyid=$(echo $job | sed "s/.*\"policyId\"\:\"\([^\"]*\).*/\1/g")

echo "policyId ${policyid}"

policy=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionPolicies/${policyid}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" 2>/dev/null)

archiveto=$(echo $policy | sed "s/.*\"vaultName\"\:\"\([^\"]*\).*/\1/g")
keeparchivefor=$(echo $policy | sed "s/.*\"snapshotArchivalCopyPolicies\".*\"daysToKeep\"\:\([0-9]*\).*\"snapshotReplicationCopyPolicies\".*/\1/g")

replicateto=$(echo $policy | sed "s/.*\"clusterName\"\:\"\([^\"]*\).*/\1/g")
keepreplicafor=$(echo $policy | sed "s/.*\"snapshotReplicationCopyPolicies\".*\"daysToKeep\"\:\([0-9]*\).*\"retries\".*/\1/g")

keeplocalfor=$(echo $policy | sed "s/.*\"daysToKeep\"\:\([0-9]*\).*/\1/g")

echo "keeping local snapshot for ${keeplocalfor} days"

remote=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/remoteClusters?names=${replicateto}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" 2>/dev/null)

remotename=$(echo $remote | sed "s/.*\"name\"\:\"\([^\'\"]*\).*/\1/g")
remoteid=$(echo $remote | sed "s/.*\"clusterId\":\([0-9]*\).*/\1/g")

echo "replicating to ${remotename} (${remoteid}) for ${keepreplicafor} days"

vault=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/vaults?name=${archiveto}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" 2>/dev/null)

vaultname=$(echo $vault | sed "s/.*\"name\"\:\"\([^\'\"]*\).*/\1/g")
vaultid=$(echo $vault | sed "s/.*\"id\":\([0-9]*\).*/\1/g")

echo "archiving to ${vaultname} (${vaultid}) for ${keeparchivefor} days"

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
