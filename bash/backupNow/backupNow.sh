#!/bin/bash

# arguments
while getopts "v:j:k:o:s:" flag
    do
             case "${flag}" in
                    v) CLUSTER_ENDPOINT=${OPTARG};;
                    j) JOBNAME=${OPTARG};;
                    k) APIKEY=${OPTARG};;
                    o) SOURCENAME=${OPTARG};;
                    s) SLEEP_TIME=${OPTARG};;
             esac
    done

if [ -z "${CLUSTER_ENDPOINT}" ] || [ -z "${JOBNAME}" ] || [ -z "${APIKEY}" ]
then
    echo "Usage: ./backupNow.sh -v <cluster> -j <jobname> -k <apikey> [ -o <servername> ]"
    exit 1
fi

if [ -z "$SLEEP_TIME" ]
then
    SLEEP_TIME=120
fi

# api call function
api () {
    if [ -z "$1" ]
    then
        echo 'no api method specified'
        return 1
    else
        method=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    fi
    if [ -z "$2" ]
    then
        echo 'no uri specified'
        return 1
    else
        uri=$( echo "$2" | sed 's/ /%20/g' )
    fi
    if [ -z "$3" ]
    then
        echo 'no apikey specified'
        return 1
    fi
    if [ -z "$4" ]
    then
        data='{}'
    else
        data=$4
        # echo "${data}"
    fi
    if [ method = 'POST' ]
    then
        echo "${data}"
    fi
    API_RESPONSE=$(curl --location -k --request $method "${uri}" \
    --header "apiKey: $3" \
    --data "${data}" 2>/dev/null)
    echo "${API_RESPONSE}"
}

# get protection group

PROTECTION_GROUP=$(api get "https://${CLUSTER_ENDPOINT}/v2/data-protect/protection-groups?isActive=true&isDeleted=false&names=${JOBNAME}" $APIKEY)
PROTECTION_GROUP_NAME=$(echo $PROTECTION_GROUP | jq --raw-output '.protectionGroups[0].name')
if [ "${PROTECTION_GROUP_NAME}" == "null" ]
then
    echo "${JOBNAME} not found"
    exit 1
fi

PROTECTION_GROUP_ID=$(echo $PROTECTION_GROUP | jq --raw-output '.protectionGroups[0].id')
arrIN=(${PROTECTION_GROUP_ID//:/ })
V1_PROTECTION_GROUP_ID=${arrIN[2]}
PROTECTION_GROUP_ENVIRONMENT=$(echo $PROTECTION_GROUP | jq --raw-output '.protectionGroups[0].environment')
if [ "${PROTECTION_GROUP_ENVIRONMENT}" == "kPhysical" ]
then
    PROTECTION_GROUP_OBJECTS=$(echo $PROTECTION_GROUP | jq --raw-output '.protectionGroups[0].physicalParams.fileProtectionTypeParams.objects')
fi

# get policy
POLICY_ID=$(echo $PROTECTION_GROUP | jq --raw-output '.protectionGroups[0].policyId')
POLICY=$(api get "https://${CLUSTER_ENDPOINT}/irisservices/api/v1/public/protectionPolicies/$POLICY_ID" $APIKEY)
RUN_PARAMS='{"copyRunTargets": [], "runNowParameters": [], "runType": "kRegular"}'

# replication targets
REPLICATION_TARGETS=$(echo $POLICY | jq --raw-output '.snapshotReplicationCopyPolicies')

if [ "${REPLICATION_TARGETS}" != "null" ]
then
    REPLICATION_TARGETS=$(echo $REPLICATION_TARGETS | jq 'unique_by(.target.clusterId)')
    while read i
    do
        REMOTE_CLUSTER_ID=$(echo $i | jq -c '.target.clusterId')
        REMOTE_CLUSTER_NAME=$(echo $i | jq -c '.target.clusterName')
        DAYS_TO_KEEP=$(echo $i | jq -c '.daysToKeep' | tr -d '"')
        
        if [ ! -z "${REMOTE_CLUSTER_ID}" ]
        then
            RUN_PARAMS=$(echo "${RUN_PARAMS}" | jq '.copyRunTargets += [{"copyPartial": true, "daysToKeep": '$DAYS_TO_KEEP', "replicationTarget": {
                "clusterId": '$REMOTE_CLUSTER_ID', 
                "clusterName": '$REMOTE_CLUSTER_NAME'}, 
                "type": "kRemote"}]')
        fi
    done <<< $(echo $REPLICATION_TARGETS | jq -c '.[]')
fi

# archival targets
ARCHIVE_TARGETS=$(echo $POLICY | jq --raw-output '.snapshotArchivalCopyPolicies')

if [ "${ARCHIVE_TARGETS}" != "null" ]
then
    ARCHIVE_TARGETS=$(echo $ARCHIVE_TARGETS | jq 'unique_by(.target.vaultId)')
    while read i
    do
        TARGET_ID=$(echo $i | jq -c '.target.vaultId')
        TARGET_NAME=$(echo $i | jq -c '.target.vaultName')
        TARGET_TYPE=$(echo $i | jq -c '.target.vaultType')
        DAYS_TO_KEEP=$(echo $i | jq -c '.daysToKeep' | tr -d '"')
        if [ ! -z "${TARGET_ID}" ]
        then
            RUN_PARAMS=$(echo "${RUN_PARAMS}" | jq '.copyRunTargets += [{
                "archivalTarget": {
                    "vaultId": '$TARGET_ID',
                    "vaultName": '$TARGET_NAME',
                    "vaultType": '$TARGET_TYPE'
                },
                "copyPartial": true,
                "daysToKeep": '$DAYS_TO_KEEP',
                "type": "kArchival"
            }]')
        fi
    done <<< $(echo $ARCHIVE_TARGETS | jq -c '.[]')
fi

# get protected object ID
if [ "${PROTECTION_GROUP_ENVIRONMENT}" == "kPhysical" ]
then
    if [ ! -z "${SOURCENAME}" ]
    then
        SOURCENAME=$(echo "${SOURCENAME}" | tr '[:lower:]' '[:upper:]')
        FOUND_OBJECT=0
        for i in $(echo $PROTECTION_GROUP_OBJECTS | jq -c '.[]')
        do
            OBJECT_NAME=$(echo $i | jq -c '.name' | tr -d '"' | tr '[:lower:]' '[:upper:]')
            OBJECT_ID=$(echo $i | jq -c '.id')
            if [ "${OBJECT_NAME}" = "${SOURCENAME}" ]; then
                RUN_PARAMS=$(echo "${RUN_PARAMS}" | jq '.runNowParameters += [{"sourceId": '$OBJECT_ID'}]')
                FOUND_OBJECT=1
                break
            fi
        done

        if [ $FOUND_OBJECT -eq 0 ]; then
            echo "${SOURCENAME} not found in job ${JOBNAME}"
            exit 1
        fi
    fi
fi

# get last run ID
LAST_RUN=$(api get "https://$CLUSTER_ENDPOINT/v2/data-protect/protection-groups/$PROTECTION_GROUP_ID/runs?numRuns=1" $APIKEY)
LAST_RUN_ID=$(echo $LAST_RUN | jq --raw-output '.runs[0].id')
LAST_RUN_STATUS=$(echo $LAST_RUN | jq --raw-output '.runs[0].localBackupInfo.status')

# check that last run is finished
if [ "$LAST_RUN_STATUS" == "Succeeded" ] || [ "$LAST_RUN_STATUS" == "Canceled" ] \
|| [ "$LAST_RUN_STATUS" == "Failed" ] || [ "$LAST_RUN_STATUS" == "Missed" ] \
|| [ "$LAST_RUN_STATUS" == "SucceededWithWarning" ] || [  "$LAST_RUN_STATUS" == "null" ]
then

    # start new run
    echo "Running ${PROTECTION_GROUP_NAME}"
    START_RUN=$(api post "https://$CLUSTER_ENDPOINT/irisservices/api/v1/public/protectionJobs/run/$V1_PROTECTION_GROUP_ID" $APIKEY "${RUN_PARAMS}")

    # wait for new run to appear
    NEW_RUN_ID=$LAST_RUN_ID
    sleep 5
    while [ "$NEW_RUN_ID" == "$LAST_RUN_ID" ]
    do
        NEW_RUN=$(api get "https://$CLUSTER_ENDPOINT/v2/data-protect/protection-groups/$PROTECTION_GROUP_ID/runs?numRuns=1" $APIKEY)
        NEW_RUN_ID=$(echo $NEW_RUN | jq --raw-output '.runs[0].id')
        if [ "$NEW_RUN_ID" == "$LAST_RUN_ID" ]
        then
            sleep $SLEEP_TIME
        fi
    done
    
    # wait for job to finish
    echo "New Run ID: ${NEW_RUN_ID}"
    sleep 5
    Finished=false
    while [ $Finished = false ]
    do
        NEW_RUN=$(api get "https://$CLUSTER_ENDPOINT/v2/data-protect/protection-groups/$PROTECTION_GROUP_ID/runs/$NEW_RUN_ID?includeObjectDetails=false" $APIKEY)
        NEW_RUN_STATUS=$(echo $NEW_RUN | jq --raw-output '.localBackupInfo.status')
        if [ "$NEW_RUN_STATUS" == "Succeeded" ] || [ "$NEW_RUN_STATUS" == "Canceled" ] \
        || [ "$NEW_RUN_STATUS" == "Failed" ] || [ "$NEW_RUN_STATUS" == "Missed" ] \
        || [ "$NEW_RUN_STATUS" == "SucceededWithWarning" ]
        then
            Finished=true
            echo "Job finished with status: ${NEW_RUN_STATUS}"
            if [ "$NEW_RUN_STATUS" == "Succeeded" ] || [ "$NEW_RUN_STATUS" == "SucceededWithWarning" ]
            then
                exit 0
            else
                exit 1
            fi
        else
            sleep $SLEEP_TIME
        fi
    done
    exit 0

# exit if job was already running
elif [ "$LAST_RUN_STATUS" == "Accepted" ] || [ "$LAST_RUN_STATUS" == "Running" ] || [ "$LAST_RUN_STATUS" == "Cancelling" ] || [ "$LAST_RUN_STATUS" == "OnHold" ]
then
    echo "**Existing run is in $LAST_RUN_STATUS state. Exiting"
fi
exit 1
