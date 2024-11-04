#!/bin/bash
PATH=$PATH:/usr/lpp/mmfs/bin/
LOG_FILE="/tmp/cohesity-postscript.log"
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
        echo "***** Unmounting $FULL_MOUNTPATH" | tee -a $LOG_FILE
        umount $FULL_MOUNTPATH | tee -a $LOG_FILE 2>&1
        echo " " | tee -a $LOG_FILE
    done

    # exit with success
    if [[ $all_mount_status -eq 0 ]]; then
        echo "***** $(date) : Script completed successfully" | tee -a $LOG_FILE
        echo " " | tee -a $LOG_FILE
        exit 0
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
