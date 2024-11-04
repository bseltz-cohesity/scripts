#!/bin/bash
PATH=$PATH:/usr/lpp/mmfs/bin/
SNAPNAME="Cohesity-$COHESITY_BACKUP_ENTITY"

echo " " >> /tmp/cohesity-prescript.log
echo "===============================================================" >> /tmp/cohesity-prescript.log
echo "***** $(date) : Script Started" >> /tmp/cohesity-prescript.log
echo "===============================================================" >> /tmp/cohesity-prescript.log
echo " " >> /tmp/cohesity-prescript.log

all_snap_status=0
# comma separated list of filesets to snap should be sent as parameter e.g. fs1/fileset1,fs2/fileset2
if [[ -n $1 ]]; then
    filesets=$(echo $1 | sed 's/,/ /g')
    for fileset in $filesets
    do
        IFS='/' read -r -a fsloc <<< "$fileset"
        FS="${fsloc[0]}"
        FSET="${fsloc[1]}"
        # delete old snapshot and create new one
        echo "***** Deleting old snapshot $FS $FSET:$SNAPNAME" >> /tmp/cohesity-prescript.log
        mmdelsnapshot $FS $FSET:$SNAPNAME >> /tmp/cohesity-prescript.log 2>&1
        echo " " >> /tmp/cohesity-prescript.log
        echo "***** Creating new snapshot $FS $FSET:$SNAPNAME" >> /tmp/cohesity-prescript.log
        mmcrsnapshot $FS $FSET:$SNAPNAME >> /tmp/cohesity-prescript.log 2>&1
        snap_status=$?
        echo " " >> /tmp/cohesity-prescript.log
        if [[ $snap_status -ne 0 ]]; then
            echo "!!!!! Snapshot creation failed for $FS $FSET:$SNAPNAME !!!!!" >> /tmp/cohesity-prescript.log
            echo " " >> /tmp/cohesity-prescript.log
            all_snap_status=1
            break
        fi
    done
    # exit with success
    if [[ $all_snap_status -eq 0 ]]; then
        echo "***** $(date) : Script completed successfully" >> /tmp/cohesity-prescript.log
        echo " " >> /tmp/cohesity-prescript.log
        exit 0
    else
        # a snapshot failed - clean up all snapshots
        for fileset in $filesets
        do
            IFS='/' read -r -a fsloc <<< "$fileset"
            FS="${fsloc[0]}"
            FSET="${fsloc[1]}"
            echo "!!!!! Deleting snapshot $FS $FSET:$SNAPNAME !!!!!" >> /tmp/cohesity-prescript.log
            mmdelsnapshot $FS $FSET:$SNAPNAME >> /tmp/cohesity-prescript.log 2>&1
            echo " " >> /tmp/cohesity-prescript.log
        done
        echo "!!!!! $(date) : Script exiting in failure !!!!!" >> /tmp/cohesity-prescript.log
        echo " " >> /tmp/cohesity-prescript.log
        exit 1
    fi
else
    # fail because no params were sent
    echo "!!!!! $(date) : No script parameters sent !!!!!" >> /tmp/cohesity-prescript.log
    echo " " >> /tmp/cohesity-prescript.log
    echo "!!!!! $(date) : Script exiting in failure !!!!!" >> /tmp/cohesity-prescript.log
    echo " " >> /tmp/cohesity-prescript.log
    exit 1
fi
exit 1