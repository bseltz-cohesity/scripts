#!/bin/bash

SCRIPT_VERSION="2025-05-04"
LOG_FILE="/home/epicadm/freeze-thaw.log"
SCRIPT_ROOT="/home/epicadm"

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

# Disks
SNAP_NAMES=("snap1" "snap2" "snap3")
DISK_NAMES=("disk1" "disk2" "disk3")
NEW_DISK_NAMES=("snapdisk1" "snapdisk2" "snapdisk3")
NEW_DISK_LUNS=("4" "5" "6")
DISK_SIZES=("1024" "512" "512")
DISK_SKUS=("PremiumV2_LRS" "PremiumV2_LRS" "PremiumV2_LRS")

# Epic settings ===========================================
IRIS_VM_NAME='EpicVM'
MOUNT_HOST_VM_NAME='MountHostVM'
FREEZE_CMD="/bin/sudo -u epicadm /epic/prd/bin/instfreeze"
THAW_CMD="/bin/sudo -u epicadm /epic/prd/bin/instthaw"

# Main ====================================================
echo "*** $(date '+%F %T') : Script version $SCRIPT_VERSION Started" | tee $LOG_FILE

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

# delete old snapshots ====================================
echo "*** $(date '+%F %T') : DELETING OLD SNAPSHOTS" | tee -a $LOG_FILE
for SNAP_NAME in "${SNAP_NAMES[@]}"; do
    az snapshot delete --name $SNAP_NAME --resource-group $RESOURCE_GROUP 2>&1 | tee -a $LOG_FILE
done

# detach and delete old disks =============================
echo "*** $(date '+%F %T') : DETACHING OLD DISKS" | tee -a $LOG_FILE
for DISK_NAME in "${NEW_DISK_NAMES[@]}"; do
    az vm disk detach -g $RESOURCE_GROUP --vm-name $MOUNT_HOST_VM_NAME --name $DISK_NAME 2>&1 | tee -a $LOG_FILE
    az disk delete -g $RESOURCE_GROUP --name $DISK_NAME -y 2>&1 | tee -a $LOG_FILE
done

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
echo "*** $(date '+%F %T') : CREATING AZURE SNAPSHOT" | tee -a $LOG_FILE
for index in "${!SNAP_NAMES[@]}"; do
    az snapshot create --name ${SNAP_NAMES[index]} --resource-group $RESOURCE_GROUP --source /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/disks/${DISK_NAMES[index]} 2>&1 | tee -a $LOG_FILE
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

# create new disks from snapshots ===========================
echo "*** $(date '+%F %T') : CREATING DISK FROM SNAPSHOT" | tee -a $LOG_FILE
for index in "${!SNAP_NAMES[@]}"; do
    az disk create \
        --resource-group $RESOURCE_GROUP \
        --name ${NEW_DISK_NAMES[index]} \
        --source /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/snapshots/${SNAP_NAMES[index]} \
        --size-gb ${DISK_SIZES[index]} \
        --sku ${DISK_SKUS[index]} 2>&1 | tee -a $LOG_FILE
    DISK_STATUS=$?
    if [ $FREEZE_STATUS -ne 0 ]
    then
        echo "!!! $(date '+%F %T') : DISK CREATION FAILED" | tee -a $LOG_FILE
        exit 1
    fi
done

# delete old snapshot (optional) ==========================
echo "*** $(date '+%F %T') : DELETING OLD SNAPSHOTS" | tee -a $LOG_FILE
for SNAP_NAME in "${SNAP_NAMES[@]}"; do
    az snapshot delete --name $SNAP_NAME --resource-group $RESOURCE_GROUP 2>&1 | tee -a $LOG_FILE
done

# attach new disk =========================================
echo "*** $(date '+%F %T') : ATTACHING DISKS TO MOUNT HOST VM" | tee -a $LOG_FILE
for index in "${!NEW_DISK_NAMES[@]}"; do
    az vm disk attach -g $RESOURCE_GROUP --vm-name Epic --lun ${NEW_DISK_LUNS[index]} --name /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/disks/${NEW_DISK_NAMES[index]} 2>&1 | tee -a $LOG_FILE
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

# optional (detach and delete old disks) ==================
# echo "*** $(date '+%F %T') : DETACHING OLD DISKS" | tee -a $LOG_FILE
# for DISK_NAME in "${NEW_DISK_NAMES[@]}"; do
#     az vm disk detach -g $RESOURCE_GROUP --vm-name $MOUNT_HOST_VM_NAME --name $DISK_NAME 2>&1 | tee -a $LOG_FILE
#     az disk delete -g $RESOURCE_GROUP --name $DISK_NAME -y 2>&1 | tee -a $LOG_FILE
# done

exit 0
