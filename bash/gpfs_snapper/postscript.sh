#!/bin/bash
PATH=$PATH:/usr/lpp/mmfs/bin/
SNAPNAME="Cohesity-$COHESITY_BACKUP_ENTITY"

echo " " >> /tmp/cohesity-postscript.log
echo "===============================================================" >> /tmp/cohesity-postscript.log
echo "***** $(date) : Script Started" >> /tmp/cohesity-postscript.log
echo "===============================================================" >> /tmp/cohesity-postscript.log
echo " " >> /tmp/cohesity-postscript.log

# comma separated list of filesets to snap should be sent as parameter e.g. fs1/fileset1,fs2/fileset2
if [[ -n $1 ]]; then
    filesets=$(echo $1 | sed 's/,/ /g')
    for fileset in $filesets
    do
        IFS='/' read -r -a fsloc <<< "$fileset"
        FS="${fsloc[0]}"
        FSET="${fsloc[1]}"
        # delete old snapshot
        echo "***** Deleting old snapshot $FS $FSET:$SNAPNAME" >> /tmp/cohesity-postscript.log
        mmdelsnapshot $FS $FSET:$SNAPNAME >> /tmp/cohesity-postscript.log 2>&1
        echo " " >> /tmp/cohesity-postscript.log
    done
    echo "***** $(date) : Script completed" >> /tmp/cohesity-postscript.log
    echo " " >> /tmp/cohesity-postscript.log
    exit 0
else
    # fail because no params were sent
    echo "!!!!! $(date) : No script parameters sent !!!!!" >> /tmp/cohesity-postscript.log
    echo " " >> /tmp/cohesity-postscript.log
    echo "!!!!! $(date) : Script exiting in failure !!!!!" >> /tmp/cohesity-postscript.log
    echo " " >> /tmp/cohesity-postscript.log
    exit 1
fi
exit 1