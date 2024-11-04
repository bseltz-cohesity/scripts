#!/bin/bash

cluster='thiscluster'  # name or IP of Cohesity cluster to connect to
username='myusername'  # username to connect to Coheity cluster
password='mypassword'  # password to connect to Cohedity cluster
domain='local'         # domain of user e.g. local or mydomain.net
jobid=74120            # v1 job ID of protection job
sourceid=72            # source ID of protection source

# replication
remotecluster='anothercluster'   # name of remote cluster to replicate to
remoteclusterid=428418101664119  # cluster ID of remote cluster to replicate to
keepreplicafor=7                 # days to retain replica

# archive
archivetarget='Minio'     # name of archive target
archivetargetid=1036695   # ID of archive target
keeparchivefor=31         # days to retain archive

auth=$(curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/accessTokens" \
    -H 'Accept: application/json' \
    -H 'Content-type: application/json' -d '{
    "password": "'${password}'",
    "username": "'${username}'",
    "domain": "'${domain}'"
}' 2>/dev/null)

token=$(echo $auth | sed "s/.*\"accessToken\":\"\([^\"]*\).*/\1/")
echo "Running backup..."
curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobs/run/${jobid}"  \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" \
    -d '{
    "copyRunTargets": [
        {
            "archivalTarget": {
                "vaultId": '${archivetargetid}',
                "vaultName": "'${archivetarget}'",
                "vaultType": "kCloud"
            },
            "copyPartial": true,
            "daysToKeep": '${keeparchivefor}',
            "type": "kArchival"
        },
        {
            "copyPartial": true,
            "daysToKeep": '${keepreplicafor}',
            "replicationTarget": {
                "clusterId": '${remoteclusterid}',
                "clusterName": "'${remotecluster}'"
            },
            "type": "kRemote"
        }
    ],
    "runNowParameters": [
        {
            "sourceId": '${sourceid}'
        }
    ],
    "runType": "kRegular"
}'
