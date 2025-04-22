#!/bin/bash

# arguments
while getopts "v:k:s:t:d:" flag
    do
             case "${flag}" in
                    v) CLUSTER_ENDPOINT=${OPTARG};;
                    k) APIKEY=${OPTARG};;
                    s) SOURCEPATH=${OPTARG};;
                    t) TARGETPATH=${OPTARG};;
                    d) TARGETDIR=${OPTARG};;
             esac
    done

if [ -z "${CLUSTER_ENDPOINT}" ] || [ -z "${SOURCEPATH}" ] || [ -z "${TARGETPATH}" ] || [ -z "${TARGETDIR}" ] || [ -z "${APIKEY}" ]
then
    echo "Usage: ./cloneDirectory.sh -v <cluster> -k <apikey> -s <sourcepath> -t <targetpath> -d <targetdir>"
    exit 1
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

CLONE_PARAMS='{"destinationDirectoryName": "'${TARGETDIR}'", "destinationParentDirectoryPath": "/'${TARGETPATH}'", "sourceDirectoryPath": "/'${SOURCEPATH}'"}'
echo "Cloning $SOURCEPATH to $TARGETPATH/$TARGETDIR"
RESULT=$(api post "https://${CLUSTER_ENDPOINT}/irisservices/api/v1/public/views/cloneDirectory" $APIKEY "${CLONE_PARAMS}")
if [[ "$RESULT" != "null" ]]; then
    echo "$RESULT"
    exit 1
else
    echo "OK"
    exit 0
fi
