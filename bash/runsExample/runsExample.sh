#!/bin/bash

# arguments
while getopts "v:u:d:p:k:n:" flag
    do
             case "${flag}" in
                    v) CLUSTER_ENDPOINT=${OPTARG};;
                    u) USERNAME=${OPTARG};;
                    d) DOMAIN=${OPTARG};;
                    p) PASSWORD=${OPTARG};;
                    k) APIKEY=${OPTARG};;
                    n) NUMRUNS=${OPTARG};;
             esac
    done

# defaults
DOMAIN=${DOMAIN:-local}
NUMRUNS=${NUMRUNS:-10}

# usage
usage(){
    echo "Usage: ./runsExample.sh -v <cluster> -u <username> -d <domain> -p <password>"
    echo "   or: ./runsExample.sh -v <cluster> -k <apikey>"
    exit 1
}

if [ -z "${CLUSTER_ENDPOINT}" ]; then
    usage
elif [ "${USERNAME}" ] && [ -z "${PASSWORD}" ]; then
    usage
elif [ -z "${USERNAME}" ] && [ -z "${APIKEY}" ]; then
    usage
fi

# usecs to date function
usecsToDate (){
    if [ -z "$1" ]; then
        echo 'no timestamp specified'
    else
        p=$(expr $(($1)) / 1000000)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            date -r "$p" +"%Y-%m-%d %H:%M:%S"
        else
            date -d "@$p" +"%Y-%m-%d %H:%M:%S"
        fi
    fi
}

# authentication
header=''
echo "connecting to ${CLUSTER_ENDPOINT}..."
if [ "${USERNAME}" ] && [ "${PASSWORD}" ]; then
    auth=$(curl -X POST -k \
        --url "https://${CLUSTER_ENDPOINT}/irisservices/api/v1/public/accessTokens" \
        -d '{
            "password": "'${PASSWORD}'",
            "username": "'${USERNAME}'",
            "domain": "'${DOMAIN}'"
        }' 2>/dev/null)

    token=$(echo $auth | jq -r '.accessToken')
    if [ ${token} == "null" ]; then
        echo "authentication failed"
        exit
    else
        header="authorization: Bearer ${token}"
    fi
else
    header="apiKey: ${APIKEY}"
fi

# get protection groups
protectionGroups=$(curl --location -k --request GET "https://${CLUSTER_ENDPOINT}/v2/data-protect/protection-groups?isActive=true&isDeleted=false" \
                        --header "${header}" 2>/dev/null)
echo $protectionGroups | jq -c '.protectionGroups[]' | while read i; do
    # protction group
    jobName=$(echo $i | jq -r '.name')
    jobId=$(echo $i | jq -r '.id')
    jobType=$(echo $i | jq -r '.environment')
    echo "$jobName ($jobType)"
    runs=$(curl --location -k --request GET "https://${CLUSTER_ENDPOINT}/v2/data-protect/protection-groups/${jobId}/runs?numRuns=${NUMRUNS}&includeObjectDetails=true" \
                --header "${header}" 2>/dev/null | sed 's/\\\\/\/\//g' | sed 's/\/\/\/\//\\\\\\\\/g')
    echo $runs | jq -c '.runs[]' | while read r; do
        # run
        localBackupInfo=$(echo $r | jq -r '.localBackupInfo')
        localBackupInfo=$(echo $localBackupInfo)
        status=$(echo $localBackupInfo | jq -r '.status')
        startTimeUsecs=$(echo $localBackupInfo | jq -r '.startTimeUsecs')
        # cloud archive direct
        if [ "${localBackupInfo}" == "null" ]; then
            status=$(echo $r | jq -r '.archivalInfo.archivalTargetResults[0].status')
            startTimeUsecs=$(echo $r | jq -r '.archivalInfo.archivalTargetResults[0].startTimeUsecs')
        fi
        startTime=$(usecsToDate "$startTimeUsecs")
        echo "    ${startTime} (${status})"
        echo $r | jq -c '.objects[]' | while read o; do
            # object
            objectName=$(echo $o | jq '.object.name' | sed 's/"//g' | sed 's/\\/\\\\/g' | sed 's/\/\//\\/g')
            objectResults=$(echo $o | jq -c '.localSnapshotInfo.snapshotInfo')
            backupFileCount=$(echo $objectResults | jq -r '.backupFileCount')
            totalFileCount=$(echo $objectResults | jq -r '.totalFileCount')
            # cloud archive direct
            if [ "${objectResults}" == "null" ]; then
                objectResults=$(echo $o | jq -c '.archivalInfo.archivalTargetResults[0]')
                backupFileCount=$(echo $objectResults | jq -r '.stats.backupFileCount')
                totalFileCount=$(echo $objectResults | jq -r '.stats.totalFileCount')
            fi
            if [ "${backupFileCount}" == "null" ]; then
                backupFileCount=0
            fi
            # object output
            objectStatus=$(echo $objectResults | jq -r '.status')
            warning=$(echo $objectResults | jq -r '.warnings[0]')
            error=$(echo $objectResults | jq -r '.errors[0]')
            message=""
            if [ "${warning}" != "null" ]; then
                message="- Warning: ${warning}"
            fi
            if [ "${error}" != "null" ]; then
                message="- Error: ${error}"
            fi
            if [ "${totalFileCount}" == "null" ]; then
                echo "        ${objectName} (${objectStatus}) ${message}"
            else
                echo "        ${objectName} (${objectStatus}) - Files Backed Up: ${backupFileCount}/${totalFileCount} ${message}"
            fi
        done
    done
done
