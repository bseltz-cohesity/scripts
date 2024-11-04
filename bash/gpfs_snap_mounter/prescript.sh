#!/bin/bash
PATH=$PATH:/usr/lpp/mmfs/bin/
LOG_FILE="/tmp/cohesity-prescript.log"
MOUNTPATH="Cohesity-$COHESITY_BACKUP_ENTITY"

echo " " | tee -a $LOG_FILE
echo "===============================================================" | tee -a $LOG_FILE
echo "***** $(date) : Script Started" | tee -a $LOG_FILE
echo "===============================================================" | tee -a $LOG_FILE
echo " " | tee -a $LOG_FILE

all_mount_status=0

# comma separated list of filesets to snap should be sent as parameter e.g. fs1/fileset1,fs2/fileset2
if [[ -n $1 ]]; then
    filesets=$(echo $1 | sed 's/,/ /g')
    for fileset in $filesets
    do
        IFS='/' read -r -a fsloc <<< "$fileset"
        FS="${fsloc[0]}"
        FSET="${fsloc[1]}"

        FULL_MOUNTPATH="/mnt/${MOUNTPATH}-${FS}-${FSET}"
        
        # make mount path
        mkdir $FULL_MOUNTPATH

        # unmount existing mount
        echo "***** Unmounting old mount $FULL_MOUNTPATH" | tee -a $LOG_FILE
        umount $FULL_MOUNTPATH

        # get latest snapshot
        echo "***** Finding latest snapshot for $FS/$FSET" | tee -a $LOG_FILE
        SNAP_DIRECTORY=""
        IFS=$'\n'
        for line in $(mmlssnapshot $FS -j $FSET | grep $FSET); do
            unset IFS
            lineparts=($line)
            VALID="${lineparts[2]}"
            if [[ "$VALID" == "Valid" ]]; then
                SNAP_DIRECTORY="${lineparts[0]}"
            fi
        done

        # bail out if there are no snapshots
        if [[ "$SNAP_DIRECTORY" == "" ]]; then
            echo "!!!!! No valid snapshot found for $FS/$FSET !!!!!" | tee -a $LOG_FILE
            echo " " | tee -a $LOG_FILE
            all_mount_status=1
            break
        fi

        # get fileset path
        echo "***** Finding path to fileset $FS $FSET" | tee -a $LOG_FILE
        REAL_PATH=""
        IFS=$'\n'
        for line in $(mmlsfileset $FS $FSET | grep -i $FSET); do
            unset IFS
            lineparts=($line)
            REAL_PATH="${lineparts[2]}"
        done
        
        # mount latest snapshot
        echo "***** Mounting latest snapshot $REAL_PATH/.snapshots/$SNAP_DIRECTORY to $FULL_MOUNTPATH" | tee -a $LOG_FILE
        mount --bind $REAL_PATH/.snapshots/$SNAP_DIRECTORY $FULL_MOUNTPATH
        mount_status=$?

        if [[ $mount_status -ne 0 ]]; then
            echo "!!!!! Mount failed for $FS/$FSET !!!!!" | tee -a $LOG_FILE
            echo " " | tee -a $LOG_FILE
            all_mount_status=1
            break
        fi
    done

    # exit with success
    if [[ $all_mount_status -eq 0 ]]; then
        echo "***** $(date) : Script completed successfully" | tee -a $LOG_FILE
        echo " " | tee -a $LOG_FILE
        exit 0
    else
        # a mount failed - clean up all mounts
        for fileset in $filesets
        do
            IFS='/' read -r -a fsloc <<< "$fileset"
            FS="${fsloc[0]}"
            FSET="${fsloc[1]}"
            FULL_MOUNTPATH="/mnt/${MOUNTPATH}-${FS}-${FSET}"
            echo "!!!!! Unmounting $FULL_MOUNTPATH !!!!!" | tee -a $LOG_FILE
            umount $FULL_MOUNTPATH | tee -a $LOG_FILE 2>&1
            echo " " | tee -a $LOG_FILE
        done
        echo "!!!!! $(date) : Script exiting in failure !!!!!" | tee -a $LOG_FILE
        echo " " | tee -a $LOG_FILE
        exit 1
    fi
else
    # fail because no params were sent
    echo "!!!!! $(date) : No script parameters sent !!!!!" | tee -a $LOG_FILE
    echo " " | tee -a $LOG_FILE
    echo "!!!!! $(date) : Script exiting in failure !!!!!" | tee -a $LOG_FILE
    echo " " | tee -a $LOG_FILE
    exit 1
fi
exit 1