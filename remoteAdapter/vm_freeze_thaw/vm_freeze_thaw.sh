#!/bin/bash

CLUSTER_API_KEY="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"
PROTECTION_GROUP_NAME="pure backup"
CLUSTER_ENDPOINT="mycluster"
CLUSTER_USER="cohesity_script"

FREEZE_CMD="/bin/sudo -u appuser /appuser/freeze_command"
THAW_CMD="/bin/sudo -u appuser /appuser/thaw_command"

MATCH_STRING="Snapshot validated"

echo "***PROTECTION GROUP NAME: $PROTECTION_GROUP_NAME"
echo "***GETTING LAST RUN DETAILS"

python ./jobRunning.py -v $CLUSTER_ENDPOINT -u $CLUSTER_USER -i -pwd $CLUSTER_API_KEY -j "$PROTECTION_GROUP_NAME"
LAST_RUN_STATUS=$?

if [ $LAST_RUN_STATUS -eq 0 ]
then
    $FREEZE_CMD
    FREEZE_STATUS=$?
    if [ $FREEZE_STATUS -eq 0 ]
    then
        python ./backupNow.py -v $CLUSTER_ENDPOINT -u $CLUSTER_USER -i -p $CLUSTER_API_KEY -j "$PROTECTION_GROUP_NAME" -w -es "$MATCHSTRING"
        RUN_STATUS=$?
        if [ $RUN_STATUS -eq 0 ]
        then
            echo "*** JOB RUN STATE: SUCCESSFUL"
        else
            echo "*** JOB RUN STATE:: UNSUCCESSFUL"
        fi
        ${THAW_CMD}
    else
        echo "*** FREEZE: UNSUCCESSFUL"
    fi
else
    echo "*** JOB: ALREADY RUNNING"
fi
