#!/bin/bash

NFS_PATH='ve4:/raExample'
MOUNT_PATH='/mnt/raExample/'

# Mount the Cohesity View
sudo mount -t nfs -o soft,intr,noatime,retrans=1000,timeo=900,retry=5,rsize=1048576,wsize=1048576,nolock $NFS_PATH $MOUNT_PATH 
LAST_ERROR=$?
if [ $LAST_ERROR -ne 0 ]
then
    echo "!!! $(date '+%F %T') : MOUNTING OF VIEW FAILED! ABORTING SCRIPT"
    exit $LAST_ERROR
fi

# Perform backup commands
cp /home/myuser/*.sh $MOUNT_PATH

LAST_ERROR=$?
if [ $LAST_ERROR -ne 0 ]
then
    echo "!!! $(date '+%F %T') : BACKUP COMMANDS FAILED!"
fi

# Unmount Cohesity View
sudo umount $MOUNT_PATH
exit $LAST_ERROR
