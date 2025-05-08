#!/bin/bash

SCRIPT_VERSION="2025-05-08"
LOG_FILE="/home/epicadm/freezethaw.log"
SCRIPT_ROOT="/home/epicadm"
SLEEP_SECONDS=60
DISK_PREFIX="cohdisk"
SNAP_PREFIX="cohsnap"

# cohesity cluster settings ===============================
CLUSTER_API_KEY="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
PROTECTION_GROUP_NAME="My Protection Group"
CLUSTER_ENDPOINT="mycluster.mydomain.net"
CLUSTER_USER="myuser"

# Azure settings ==========================================
SUBSCRIPTION_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
TENANT_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
APP_ID="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
SECRET="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

RESOURCE_GROUP="Epic_group"
DISK_SKU="PremiumV2_LRS"
IRIS_VM_NAME='IrisVM'
MOUNT_HOST_VM_NAME='MountVM'

# Disks
DISK_NAMES=("data0" "data1")

# Epic settings ===========================================
FREEZE_CMD="/epic/prd/bin/instfreeze"
THAW_CMD="/epic/prd/bin/instthaw"

# Main ====================================================
set -o pipefail

echo "*** $(date '+%F %T') : SCRIPT VERSION $SCRIPT_VERSION STARTED" | tee $LOG_FILE

DATE_STRING="$(date '+%F-%T')"
DATE_STRING="${DATE_STRING//:/-}"

# check for existing run ==================================
echo "*** $(date '+%F %T') : CHECKING PROTECTION GROUP '$PROTECTION_GROUP_NAME' FOR EXISTING RUN" | tee -a $LOG_FILE 
$SCRIPT_ROOT/jobRunning -v $CLUSTER_ENDPOINT -u $CLUSTER_USER -i -pwd $CLUSTER_API_KEY -j "$PROTECTION_GROUP_NAME" 2>&1 | tee -a $LOG_FILE
LAST_RUN_STATUS=$?
if [ $LAST_RUN_STATUS -ne 0 ]
then
    echo "!!! $(date '+%F %T') : PROTECTION GROUP IS ALREADY RUNNING. ABORTING SCRIPT" | tee -a $LOG_FILE
    exit 1
fi

# azure cli login =========================================
echo "*** $(date '+%F %T') : AZURE CLI AUTHENTICATING" | tee -a $LOG_FILE
az login --service-principal -t $TENANT_ID -u $APP_ID -p $SECRET 2>&1 | tee -a $LOG_FILE
LOGIN_STATUS=$?
if [ $LOGIN_STATUS -ne 0 ]
then
    echo "!!! $(date '+%F %T') : FAILED TO AUTHENTICATE AZURE CLI. ABORTING SCRIPT" | tee -a $LOG_FILE
    exit 1
fi

# set default subscription
echo "*** $(date '+%F %T') : AZURE CLI SETTING DEFAULT SUBSCRIPTION" | tee -a $LOG_FILE
az account set -s $SUBSCRIPTION_ID 2>&1 | tee -a $LOG_FILE
SUB_STATUS=$?
if [ $SUB_STATUS -ne 0 ]
then
    echo "!!! $(date '+%F %T') : FAILED TO SET DEFAULT SUBSCRIPTION. ABORTING SCRIPT" | tee -a $LOG_FILE
    exit 1
fi

# freeze Iris =============================================
echo "*** $(date '+%F %T') : STARTING FREEZE" | tee -a $LOG_FILE
$FREEZE_CMD 2>&1 | tee -a $LOG_FILE
FREEZE_STATUS=$?
if [ $FREEZE_STATUS -eq 0 ]
then
    echo "*** $(date '+%F %T') : FREEZE SUCCESSFUL" | tee -a $LOG_FILE
else
    echo "!!! $(date '+%F %T') : FREEZE FAILED" | tee -a $LOG_FILE
    exit 1
fi

# create new snapshots ====================================
echo "*** $(date '+%F %T') : CREATING NEW SNAPSHOTS" | tee -a $LOG_FILE
for DISK_NAME in "${DISK_NAMES[@]}"; do
    SNAP_NAME="${SNAP_PREFIX}-${DISK_NAME}-${DATE_STRING}"
    az snapshot create --name $SNAP_NAME --resource-group $RESOURCE_GROUP --source $DISK_NAME --incremental true 2>&1 | tee -a $LOG_FILE
    SNAP_STATUS=$?
    if [ $SNAP_STATUS -ne 0 ]
    then
        echo "!!! $(date '+%F %T') : SNAPSHOT CREATION FAILED" | tee -a $LOG_FILE
        # thaw Iris =======================================
        echo "*** $(date '+%F %T') : STARTING THAW" | tee -a $LOG_FILE
        ${THAW_CMD} 2>&1 | tee -a $LOG_FILE
        THAW_STATUS=$?
        if [ $FREEZE_STATUS -eq 0 ]
        then
            echo "*** $(date '+%F %T') : THAW SUCCESSFUL" | tee -a $LOG_FILE
            exit 1
        else
            echo "!!! $(date '+%F %T') : THAW FAILED" | tee -a $LOG_FILE
            exit 1
        fi
    fi
done

# thaw Iris ===============================================
echo "*** $(date '+%F %T') : STARTING THAW" | tee -a $LOG_FILE
${THAW_CMD} 2>&1 | tee -a $LOG_FILE
THAW_STATUS=$?
if [ $FREEZE_STATUS -eq 0 ]
then
    echo "*** $(date '+%F %T') : THAW SUCCESSFUL" | tee -a $LOG_FILE
else
    echo "!!! $(date '+%F %T') : THAW FAILED" | tee -a $LOG_FILE
    exit 1
fi

# detach old disks =============================
echo "*** $(date '+%F %T') : DETACHING OLD DISKS FROM MOUNT HOST $MOUNT_HOST_VM_NAME" | tee -a $LOG_FILE
for DISK_NAME in "${DISK_NAMES[@]}"; do
    NEW_DISK_NAME="${DISK_PREFIX}-${DISK_NAME}"
    az vm disk detach -g $RESOURCE_GROUP --vm-name $MOUNT_HOST_VM_NAME --name $NEW_DISK_NAME 2>&1 | tee -a $LOG_FILE
done

# delete old disks =============================
echo "*** $(date '+%F %T') : DELETING OLD DISKS" | tee -a $LOG_FILE
for DISK_NAME in "${DISK_NAMES[@]}"; do
    NEW_DISK_NAME="${DISK_PREFIX}-${DISK_NAME}"
    az disk delete -g $RESOURCE_GROUP --name $NEW_DISK_NAME -y 2>&1 | tee -a $LOG_FILE
done

# wait for snapshots to complete ===========================
echo "*** $(date '+%F %T') : WAITING FOR SNAPSHOT COMPLETION" | tee -a $LOG_FILE
echo ""
COMPLETE=0
while [ $COMPLETE -eq 0 ]; do
    COMPLETE=1
    echo "=========================================="
    for DISK_NAME in "${DISK_NAMES[@]}"; do
        SNAP_NAME="${SNAP_PREFIX}-${DISK_NAME}-${DATE_STRING}"
        PERCENT_COMPLETE=$(az snapshot show -n $SNAP_NAME -g $RESOURCE_GROUP --query completionPercent)
        echo "${SNAP_NAME} : ${PERCENT_COMPLETE}"
        if [ $PERCENT_COMPLETE != "100.0" ]
        then
            COMPLETE=0
            sleep $SLEEP_SECONDS
            break
        fi
    done
    echo "=========================================="
    echo ""
done

# create new disks from snapshots ===========================
echo "*** $(date '+%F %T') : CREATING DISKS FROM SNAPSHOTS" | tee -a $LOG_FILE

ZONE=$(az vm show -g $RESOURCE_GROUP -n $MOUNT_HOST_VM_NAME --query zones[0])
ZONE="${ZONE//\"/}"

for DISK_NAME in "${DISK_NAMES[@]}"; do
    SNAP_NAME="${SNAP_PREFIX}-${DISK_NAME}-${DATE_STRING}"
    NEW_DISK_NAME="${DISK_PREFIX}-${DISK_NAME}"
    NEW_DISK_SIZE=$(az disk show -g $RESOURCE_GROUP -n $DISK_NAME --query diskSizeGB)
    az disk create -g $RESOURCE_GROUP -n $NEW_DISK_NAME --source /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/snapshots/$SNAP_NAME --sku $DISK_SKU --zone $ZONE --size-gb $NEW_DISK_SIZE 2>&1 | tee -a $LOG_FILE
    DISK_STATUS=$?
    if [ $FREEZE_STATUS -ne 0 ]
    then
        echo "!!! $(date '+%F %T') : DISK CREATION FAILED" | tee -a $LOG_FILE
        exit 1
    fi
done

# attach new disks =========================================
echo "*** $(date '+%F %T') : ATTACHING DISKS TO MOUNT HOST VM" | tee -a $LOG_FILE

for DISK_NAME in "${DISK_NAMES[@]}"; do
    NEW_DISK_NAME="${DISK_PREFIX}-${DISK_NAME}"
    az vm disk attach -g $RESOURCE_GROUP --vm-name $MOUNT_HOST_VM_NAME -n $NEW_DISK_NAME 2>&1 | tee -a $LOG_FILE
    ATTACH_STATUS=$?
    if [ $ATTACH_STATUS -ne 0 ]
    then
        echo "!!! $(date '+%F %T') : DISK ATTACH FAILED" | tee -a $LOG_FILE
        exit 1
    fi
done

# run backup ==============================================
echo "*** $(date '+%F %T') : STARTING PROTECTION GROUP '$PROTECTION_GROUP_NAME'" | tee -a $LOG_FILE
$SCRIPT_ROOT/backupNow -v $CLUSTER_ENDPOINT -u $CLUSTER_USER -i -p $CLUSTER_API_KEY -j "$PROTECTION_GROUP_NAME" -q -s 10 2>&1 | tee -a $LOG_FILE
RUN_STATUS=$?
if [ $RUN_STATUS -eq 0 ]
then
    echo "*** $(date '+%F %T') : PROTECTION GROUP STATUS: SUCCESSFUL" | tee -a $LOG_FILE
else
    echo "!!! $(date '+%F %T') : PROTECTION GROUP STATUS: UNSUCCESSFUL" | tee -a $LOG_FILE
    exit 1
fi

# delete old snapshots ==========================
echo "*** $(date '+%F %T') : DELETING OLD SNAPSHOTS" | tee -a $LOG_FILE
for DISK_NAME in "${DISK_NAMES[@]}"; do
    SNAP_NAME="${SNAP_PREFIX}-${DISK_NAME}-${DATE_STRING}"
    echo "*** $(date '+%F %T') : KEEPING NEW SNAPSHOT $SNAP_NAME" | tee -a $LOG_FILE
    DISK_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/disks/$DISK_NAME"
    SNAPSHOTS=$(az snapshot list -g $RESOURCE_GROUP --query "[?creationData.sourceResourceId == '$DISK_RESOURCE_ID']")
    echo $SNAPSHOTS | jq -r '.[]|[.name] | @tsv' | while read snap; do
        if [ "$SNAP_NAME" != "$snap" ]
        then
            echo "*** $(date '+%F %T') : DELETING OLD SNAPSHOT $snap" | tee -a $LOG_FILE
            az snapshot delete --name $snap --resource-group $RESOURCE_GROUP 2>&1 | tee -a $LOG_FILE
        fi
    done
done

set +o pipefail
echo "*** $(date '+%F %T') : SCRIPT COMPLETED SUCCESSFULLY" | tee -a $LOG_FILE
exit 0
