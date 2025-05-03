#!/bin/bash

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
DISK_SIZES=("1024" "512" "512")
DISK_SKUS=("PremiumV2_LRS" "PremiumV2_LRS" "PremiumV2_LRS")

# Epic settings ===========================================
IRIS_VM_NAME='EpicVM'
MOUNT_HOST_VM_NAME='MountHostVM'
FREEZE_CMD="/bin/sudo -u epicadm /epic/prd/bin/instfreeze"
THAW_CMD="/bin/sudo -u epicadm /epic/prd/bin/instthaw"

# =========================================================

# check for existing run ==================================
echo "*** PROTECTION GROUP NAME: $PROTECTION_GROUP_NAME"
echo "*** CHECKING FOR EXISTING RUN"
$SCRIPT_ROOT/jobRunning -v $CLUSTER_ENDPOINT -u $CLUSTER_USER -i -pwd $CLUSTER_API_KEY -j "$PROTECTION_GROUP_NAME"
LAST_RUN_STATUS=$?
if [ $LAST_RUN_STATUS -ne 0 ]
then
    echo "!!! PROTECTION GRUP IS ALREADY RUNNING. ABORTING SCRIPT"
    exit 1
fi

# azure cli login =========================================
echo "*** AZURE CLI AUTHENTICATING"
az login --service-principal -t $TENANT_ID -u $APP_ID -p $SECRET
LOGIN_STATUS=$?
if [ $LOGIN_STATUS -ne 0 ]
then
    echo "!!! FAILED TO AUTHENTICATE AZURE CLI. ABORTING SCRIPT"
    exit 1
fi

# delete old snapshots ====================================
echo "*** DELETING OLD SNAPSHOTS"
for SNAP_NAME in "${SNAP_NAMES[@]}"; do
    az snapshot delete --name $SNAP_NAME --resource-group $RESOURCE_GROUP
done

# detach and delete old disks =============================
echo "*** DETACHING OLD DISKS"
for DISK_NAME in "${NEW_DISK_NAMES[@]}"; do
    az vm disk detach -g $RESOURCE_GROUP --vm-name $MOUNT_HOST_VM_NAME --name $DISK_NAME
    az disk delete -g $RESOURCE_GROUP --name $DISK_NAME -y
done

# freeze Iris =============================================
echo "*** STARTING FREEZE"
$FREEZE_CMD
FREEZE_STATUS=$?
if [ $FREEZE_STATUS -eq 0 ]
then
    echo "*** FREEZE SUCCESSFUL"
else
    echo "!!! FREEZE FAILED"
    exit 1
fi

# create new snapshots ====================================
echo "*** CREATING AZURE SNAPSHOT"
for index in "${!SNAP_NAMES[@]}"; do
    az snapshot create --name ${SNAP_NAMES[index]} --resource-group $RESOURCE_GROUP --source /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/disks/${DISK_NAMES[index]}
    SNAP_STATUS=$?
    if [ $SNAP_STATUS -ne 0 ]
    then
        echo "!!! SNAPSHOT CREATION FAILED"
        # thaw Iris =======================================
        echo "*** STARTING THAW"
        ${THAW_CMD}
        THAW_STATUS=$?
        if [ $FREEZE_STATUS -eq 0 ]
        then
            echo "*** THAW SUCCESSFUL"
            exit 1
        else
            echo "!!! THAW FAILED"
            exit 1
        fi
    fi
done

# thaw Iris ===============================================
echo "*** STARTING THAW"
${THAW_CMD}
THAW_STATUS=$?
if [ $FREEZE_STATUS -eq 0 ]
then
    echo "*** THAW SUCCESSFUL"
else
    echo "!!! THAW FAILED"
    exit 1
fi

# create new disks from snapshots ===========================
echo "*** CREATING DISK FROM SNAPSHOT"
for index in "${!SNAP_NAMES[@]}"; do
    az disk create \
        --resource-group $RESOURCE_GROUP \
        --name ${NEW_DISK_NAMES[index]} \
        --source /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/snapshots/${SNAP_NAMES[index]} \
        --size-gb ${DISK_SIZES[index]} \
        --sku ${DISK_SKUS[index]}
    DISK_STATUS=$?
    if [ $FREEZE_STATUS -ne 0 ]
    then
        echo "!!! DISK CREATION FAILED"
        exit 1
    fi
done

# delete old snapshot (optional) ==========================
echo "*** DELETING OLD SNAPSHOTS"
for SNAP_NAME in "${SNAP_NAMES[@]}"; do
    az snapshot delete --name $SNAP_NAME --resource-group $RESOURCE_GROUP
done

# attach new disk =========================================
echo "*** ATTACHING DISKS TO MOUNT HOST VM"
for DISK_NAME in "${NEW_DISK_NAMES[@]}"; do
    az vm disk attach -g $RESOURCE_GROUP --vm-name Epic --name /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Compute/disks/$DISK_NAME
    ATTACH_STATUS=$?
    if [ $ATTACH_STATUS -ne 0 ]
    then
        echo "!!! DISK ATTACH FAILED"
        exit 1
    fi
done

# run backup ==============================================
echo "*** STARTING PROTECTION RUN" 
$SCRIPT_ROOT/backupNow -v $CLUSTER_ENDPOINT -u $CLUSTER_USER -i -p $CLUSTER_API_KEY -j "$PROTECTION_GROUP_NAME" -q -s 10
RUN_STATUS=$?
if [ $RUN_STATUS -eq 0 ]
then
    echo "*** RUN START STATE: SUCCESSFUL"
else
    echo "*** RUN START STATE:: UNSUCCESSFUL"
    exit 1
fi

# optional (detach and delete old disks) ==================
# echo "*** DETACHING OLD DISKS"
# for DISK_NAME in "${NEW_DISK_NAMES[@]}"; do
#     az vm disk detach -g $RESOURCE_GROUP --vm-name $MOUNT_HOST_VM_NAME --name $DISK_NAME
#     az disk delete -g $RESOURCE_GROUP --name $DISK_NAME -y
# done

exit 0
