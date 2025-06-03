#!/bin/bash

SCRIPT_VERSION="2025-06-03"

# Iris host settings
IRIS_USER="epicadm"
IRIS_HOST="192.168.1.251"
FREEZE_CMD="/epic/prd/bin/instfreeze"
THAW_CMD="/epic/prd/bin/instthaw"

# storage array settings
NIMBLE_USER="admin"
NIMBLE_ARRAY="192.168.1.17"
VOL_NAMES=("EPICODB-1" "EPICODB-2" "EPICODB-3")

# mount host settings
MOUNT_PATH="/epic/prd"
VOLUME_GROUP="epicodb"
LOGICAL_VOLUME="lvol0"

echo "*** $(date '+%F %T') : SCRIPT VERSION $SCRIPT_VERSION STARTED" 

# (MOUNT HOST) unmount previous volume
sudo umount $MOUNT_PATH
sudo vgchange -an $VOLUME_GROUP
LAST_STATUS=$?
if [ $LAST_STATUS -ne 0 ]
then
    echo "!!! $(date '+%F %T') : FAILED TO UNMOUNT $MOUNT_PATH. ABORTING SCRIPT"
    exit 1
fi

# (STORAGE ARRAY) delete previous snapshot volume
for VOL_NAME in "${VOL_NAMES[@]}"; do
    echo "Deleting Old Clone Volume ${VOL_NAME}-CLONE"
    ssh $NIMBLE_USER@$NIMBLE_ARRAY "vol --offline ${VOL_NAME}-CLONE --force"
    ssh $NIMBLE_USER@$NIMBLE_ARRAY "vol --delete ${VOL_NAME}-CLONE --force"
    ssh $NIMBLE_USER@$NIMBLE_ARRAY "snap --delete ${VOL_NAME}-SNAP --vol $VOL_NAME --force"
    LAST_STATUS=$?
    if [ $LAST_STATUS -ne 0 ]
    then
        echo "!!! $(date '+%F %T') : FAILED TO DELETE $VOL_NAME. ABORTING SCRIPT"
        exit 1
    fi
done

# (IRIS HOST) freeze epic prod
echo "Freezing"
ssh $IRIS_USER@$IRIS_HOST $FREEZE_CMD
LAST_STATUS=$?
if [ $LAST_STATUS -ne 0 ]
then
    echo "!!! $(date '+%F %T') : FAILED TO FREEZE. ABORTING SCRIPT"
    exit 1
fi

# (STORAGE ARRAY) clone volumes
for VOL_NAME in "${VOL_NAMES[@]}"; do
    echo "Cloning Volume $VOL_NAME"
    ssh $NIMBLE_USER@$NIMBLE_ARRAY "vol --snap $VOL_NAME --snapname ${VOL_NAME}-SNAP"
    ssh $NIMBLE_USER@$NIMBLE_ARRAY "vol --clone $VOL_NAME --clonename ${VOL_NAME}-CLONE --snapname ${VOL_NAME}-SNAP"
    LAST_STATUS=$?
    if [ $LAST_STATUS -ne 0 ]
    then
        echo "!!! $(date '+%F %T') : FAILED TO CLONE $VOL_NAME. ABORTING SCRIPT"
    fi
done

# (IRIS HOST) thaw epic prod
echo "Thawing"
ssh $IRIS_USER@$IRIS_HOST $THAW_CMD
THAW_STATUS=$?
if [ $THAW_STATUS -ne 0 ]
then
    echo "!!! $(date '+%F %T') : FAILED TO THAW. ABORTING SCRIPT"
    exit 1
fi

if [ $LAST_STATUS -ne 0 ]
then
    exit 1
fi

# (MOUNT HOST) mount volume group
echo "Mounting volume group"
sudo iscsiadm -m discovery -t sendtargets -p $NIMBLE_ARRAY
sudo iscsiadm -m node --login
sudo pvscan
sudo vgscan
sudo lvscan
sudo mkdir -p $MOUNT_PATH
sudo vgchange -ay $VOLUME_GROUP
sudo mount /dev/mapper/${VOLUME_GROUP}-${LOGICAL_VOLUME} $MOUNT_PATH
LAST_STATUS=$?
if [ $LAST_STATUS -ne 0 ]
then
    echo "!!! $(date '+%F %T') : FAILED TO MOUNT VOLUME GROUP. ABORTING SCRIPT"
    exit 1
fi
echo "*** $(date '+%F %T') : SCRIPT COMPLETED SUCCESSFULLY" 
exit 0
