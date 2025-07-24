#!/bin/bash

CLUSTER_API_KEY="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
PROTECTION_GROUP_NAME="My Protection Group"
CLUSTER_ENDPOINT="mycluster.mydomain.net"
CLUSTER_USER="myuser"
SCRIPT_ROOT="/epic"

FREEZE_CMD="/bin/sudo -u epicadm /epic/prd/bin/instfreeze"
THAW_CMD="/bin/sudo -u epicadm /epic/prd/bin/instthaw"

MATCH_STRING="created successfully"

echo "*** PROTECTION GROUP NAME: $PROTECTION_GROUP_NAME"
echo "*** CHECKING FOR EXISTING RUN"

python $SCRIPT_ROOT/jobRunning.py -v $CLUSTER_ENDPOINT -u $CLUSTER_USER -i -pwd $CLUSTER_API_KEY -j "$PROTECTION_GROUP_NAME"
LAST_RUN_STATUS=$?

if [ $LAST_RUN_STATUS -eq 0 ]
then
    echo "*** STARTING FREEZE"
    $FREEZE_CMD
    FREEZE_STATUS=$?
    if [ $FREEZE_STATUS -eq 0 ]
    then
        echo "*** FREEZE SUCCESSFUL"
        echo "*** STARTING PROTECTION RUN" 
        python $SCRIPT_ROOT/backupNow.py -v $CLUSTER_ENDPOINT -u $CLUSTER_USER -i -p $CLUSTER_API_KEY -j "$PROTECTION_GROUP_NAME" -t kFull -q -s 10 -es "$MATCH_STRING"
        RUN_STATUS=$?
        if [ $RUN_STATUS -eq 0 ]
        then
            echo "*** RUN START STATE: SUCCESSFUL"
        else
            echo "*** RUN START STATE:: UNSUCCESSFUL"
        fi
        echo "*** STARTING THAW"
        ${THAW_CMD}
        THAW_STATUS=$?
        if [ $FREEZE_STATUS -eq 0 ]
        then
            echo "*** THAW SUCCESSFUL"
            exit 0
        else
            echo "*** THAW FAILED"
            exit 1
        fi
    else
        echo "*** FREEZE: UNSUCCESSFUL"
        exit 1
    fi
else
    echo "*** JOB: ALREADY RUNNING"
    exit 0
fi
