#!/bin/bash

cluster='mycluster'
username='myusername'
password='mypassword'
domain='mydomain.net'
jobname='myjobname'
sourceserver='server1.mydomain.net'
sourcepath='/home/myusername/documents'
targetserver='server2.mydomain.net'
targetpath='/tmp/restoretest'

# authenticate
echo "connecting to ${cluster}..."
auth=$(curl -X POST -k \
    --url "https://${cluster}/irisservices/api/v1/public/accessTokens" \
    -H 'Accept: application/json' \
    -H 'Content-type: application/json' -d '{
    "password": "'${password}'",
    "username": "'${username}'",
    "domain": "'${domain}'"
}' 2>/dev/null)

token=$(echo $auth | jq -r '.accessToken')

# find job
jobname=$(echo $jobname | sed "s/ /%20/g")

job=$(curl -X GET -k \
    --url "https://${cluster}/irisservices/api/v1/public/protectionJobs?names=${jobname}" \
    -H 'Content-type: application/json' \
    -H "authorization: Bearer ${token}" 2>/dev/null)

jobid=$(echo $job | jq -r '.[0].id')
jobName=$(echo $job | jq -r '.[0].name')

# wait for existing job run to finish
finishedStates=(kCanceled kSuccess kFailure)
status="kRunning"
echo "waiting for existing job runs to finish..."
while [[ ! " ${finishedStates[@]} " =~ " ${status} " ]]
do
    sleep 1
    run=$(curl -X GET -k \
        --url "https://${cluster}/irisservices/api/v1/public/protectionRuns?jobId=${jobid}&numRuns=1"  \
        -H 'Content-type: application/json' \
        -H "authorization: Bearer ${token}" 2>/dev/null)
    status=$(echo $run | jq -r '.[0].backupRun.status')
done

# find source server
search=$(curl -X GET -k \
       --url "https://${cluster}/irisservices/api/v1/searchvms?entityTypes=kPhysical&vmName=${sourceserver}" \
       -H 'Content-type: application/json' \
       -H "authorization: Bearer ${token}" 2>/dev/null)

echo $search | jq -c '.vms[]' | while read i
do
    thisjob=$(echo $i | jq -r '.vmDocument.jobName')
    if [ "$thisjob" = "$jobName" ]; then
        sourceentity=$(echo $i | jq -r '.vmDocument.objectId.entity')
        version=$(echo $i | jq -r '.vmDocument.versions[0]')
        jobInstanceId=$(echo $version | jq -r '.instanceId.jobInstanceId')
        jobStartTimeUsecs=$(echo $version | jq -r '.instanceId.jobStartTimeUsecs')
        jobUid=$(echo $i | jq -r '.vmDocument.objectId.jobUid')

        physicalServerNode=$(curl -X GET -k \
                        --url "https://${cluster}/irisservices/api/v1/backupsources?allUnderHierarchy=true&envTypes=6&excludeTypes=5&excludeTypes=10&onlyReturnOneLevel=true" \
                        -H 'Content-type: application/json' \
                        -H "authorization: Bearer ${token}" 2>/dev/null)

        psid=$(echo $physicalServerNode | jq -r '.entityHierarchy.children[0].entity.id')

        # find target server
        physicalServers=$(curl -X GET -k \
                        --url "https://${cluster}/irisservices/api/v1/backupsources?allUnderHierarchy=true&entityId=${psid}&excludeTypes=5&excludeTypes=10&includeVMFolders=true" \
                        -H 'Content-type: application/json' \
                        -H "authorization: Bearer ${token}" 2>/dev/null)

        echo $physicalServers | jq -c '.entityHierarchy.children[]' | while read i
        do
            thisserver=$(echo $i | jq -r '.entity.physicalEntity.name' 2>/dev/null)
            ltargetserver=$(echo $targetserver | tr '[A-Z]' '[a-z]')
            lthisserver=$(echo $thisserver | tr '[A-Z]' '[a-z]')

            # find target server
            if [ "$ltargetserver" = "$lthisserver" ] ; then
                targetEntity=$(echo $i | jq -r '.entity')
                now=$(echo $(date | tr '[ ,:]' '[_,_]'))

                # restore parameters
                payload='{
                    "filenames": [
                        "'${sourcepath}'"
                    ],
                    "sourceObjectInfo": {
                        "jobId": '${jobid}',
                        "jobInstanceId": '${jobInstanceId}',
                        "startTimeUsecs": '${jobStartTimeUsecs}',
                        "entity": '${sourceentity}',
                        "jobUid": '${jobUid}'
                    },
                    "params": {
                        "targetEntity": '${targetEntity}',
                        "targetEntityCredentials": {
                            "username": "",
                            "password": ""
                        },
                        "restoreFilesPreferences": {
                            "restoreToOriginalPaths": false,
                            "overrideOriginals": true,
                            "preserveTimestamps": true,
                            "preserveAcls": true,
                            "preserveAttributes": true,
                            "continueOnError": false,
                            "alternateRestoreBaseDirectory": "'${targetpath}'"
                        }
                    },
                    "name": "Recover-Files_'${now}'"
                }'

                # perform restore
                echo "performing restore..."
                restore=$(curl -X POST -k \
                        --url "https://${cluster}/irisservices/api/v1/restoreFiles" \
                        -H 'Accept: application/json' \
                        -H 'Content-type: application/json' -d "${payload}" \
                        -H "authorization: Bearer ${token}" 2>/dev/null)

                # wait for restore to complete
                taskId=$(echo $restore | jq -r '.restoreTask.performRestoreTaskState.base.taskId')
                status="kRunning"
                while [[ ! " ${finishedStates[@]} " =~ " ${status} " ]]
                do
                    sleep 1
                    restoretask=$(curl -X GET -k \
                        --url "https://${cluster}/irisservices/api/v1/restoretasks/${taskId}"  \
                        -H 'Content-type: application/json' \
                        -H "authorization: Bearer ${token}" 2>/dev/null)
                    status=$(echo $restoretask | jq -r '.[0].restoreTask.performRestoreTaskState.base.publicStatus')
                    if [[ " ${finishedStates[@]} " =~ " ${status} " ]] ; then
                        echo "Restore completed with status: $status"
                    fi
                done
                break
            fi
        done
        break
    fi
done







