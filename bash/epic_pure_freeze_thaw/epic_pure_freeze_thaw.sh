#!/bin/bash

##########################################################################################
##
## Last updated: 2023.02.24 - Brian Seltzer @ Cohesity
##
## - change first line to #!/bin/ksh (AIX) or #!/bin/bash (Linux)
## - edit /etc/ssh/sshd_cohfig: MaxStartups 50:30:150 (first number must be 24 or higher) 
## - modify parameters below
## - epic luns must be in pure protection group
## - pass in comma separated list of volume groups to freeze (AIX) as pre-script parameter
## - uncomment and inspect file system freeze sections (AIX)
## - testing=1 means we will not skip freezing, testing=0 means we will freeze
##
##########################################################################################

testing=1
PRIVKEY_PATH="-i /root/.ssh/id_rsa"
PURE_USER="puresnap"
PURE_ARRAY="10.12.1.39"
PURE_SRC_PGROUP="EpicProtectionGroup108"

echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Started" >> /tmp/cohesity_snap.log

if [[ ! -e /tmp/cohesity_snap.log ]]; then
    touch /tmp/cohesity_snap.log
fi

if [[ ! -e /tmp/cohesity_SRCLUNS.txt ]]; then
    touch /tmp/cohesity_SRCLUNS.txt
fi

###################################
## Check if main script already run
###################################

#### If my lock already exists, we're good, exit and perform the backup
if [[ -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY ]]; then
    echo "Found Lock. Main Script Ran Already"
    if [[ -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.failed ]]; then
       echo "Failing on signal from leader ***"
       echo "$(date) : $COHESITY_BACKUP_ENTITY : Failing on signal from leader" >> /tmp/cohesity_snap.log
       rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
       exit 1
    fi
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed Successfully" >> /tmp/cohesity_snap.log
    rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
    exit 0
fi

##########################
## If Not Create Lock File
##########################

#### Try to take leader role
mkdirstatus=1
if [[ ! -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX ]]; then
    mkdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX 
    mkdirstatus=$?
fi

#### If not the leader, wait for my lock to appear then exit and perform the backup
if [[ $mkdirstatus -ne 0 ]]; then
    echo "Snapshot script already running. Waiting for Main Script to complete"
    while [[ -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX ]]; do
        sleep 1
    done 
    echo "Done Waiting."
    if [[ -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.failed ]]; then
        echo "Failing on signal from leader ***"
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Failing on signal from leader" >> /tmp/cohesity_snap.log
        rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
        exit 1
    fi
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed Successfully" >> /tmp/cohesity_snap.log
    rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
    exit 0
fi

#################################################
## I'm the leader, continue to freeze, snap, thaw
#################################################

echo "" >> /tmp/cohesity_snap.log
echo "################# Backup For $(date) #########################" >> /tmp/cohesity_snap.log
echo "COHESITY_BACKUP_ENTITY:$COHESITY_BACKUP_ENTITY" 
echo "COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX:$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX" 
echo "Cohesity Pre Script Starting.\n"
echo "################# Script Leader ########################"
echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Running as Leader" >> /tmp/cohesity_snap.log
echo "$(date) : $COHESITY_BACKUP_ENTITY : Cohesity Pre-Script starting with PID $$" >> /tmp/cohesity_snap.log
echo "$(date) Created Lock /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX" 

############################
## Generate Source LUN Locks
############################

#### Get list of volumes in pure protection group
echo "Generating Source LUN File /tmp/cohesity_SRCLUNS.txt" 
/usr/bin/ssh ${PRIVKEY_PATH} ${PURE_USER}@${PURE_ARRAY} "purepgroup listobj --type vol ${PURE_SRC_PGROUP}"  > /tmp/cohesity_SRCLUNS.txt
if [[ $? -ne 0 ]]; then
    echo "Obtaining Pure Source LUNs Failed"
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Obtaining Pure Source LUNs Failed ****" >> /tmp/cohesity_snap.log
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log
    mkdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.failed
    rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX >> /tmp/cohesity_snap.log 2>&1
    rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
    exit 4
fi

PURE_SRC_LUNS=$(sed -e :a -e '$!N; s/\n/ /; ta' /tmp/cohesity_SRCLUNS.txt)
echo "PURE_SOURCE_LUNS: $PURE_SRC_LUNS"

#### make volume locks
for jj in $PURE_SRC_LUNS
do
    mkdir -p /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$jj
done

if [[ ! -e /tmp/$COHESITY_JOB_ID ]]; then
    mkdir /tmp/$COHESITY_JOB_ID
    journalStatus=$?
fi

if [[ $journalStatus -ne 0 ]]; then
    echo "Found Current Snapshot Suffix  $COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX in Journal, Exiting."
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed Successfully" >> /tmp/cohesity_snap.log
    exit 0
fi

##################
## Freeze Database
##################

echo "Freezing Database"
echo "$(date) : $COHESITY_BACKUP_ENTITY : Freezing Database" >> /tmp/cohesity_snap.log

##### Testing
if [[ $testing -eq 1 ]]; then
    freeze_status=0
    fsfreeze_status=0
else
	# /opt/scripts/ZBACKUP/freeze.sh
    freeze_status=$?
fi

if [[ $freeze_status -ne 0 ]]; then
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Database Freeze Failed: $freeze_status"  >> /tmp/cohesity_snap.log
    echo "Database Freeze Failed: $freeze_status"
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log
    mkdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.failed
	rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX >> /tmp/cohesity_snap.log 2>&1
    rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
    exit 1
else
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Database Freeze Successful" >> /tmp/cohesity_snap.log
    echo "Database Freeze Successful."
fi

#####################
## Freeze Filesystems
#####################

##### comma separated list of volgroups to freeze (from script parameter)
# typeset -i fsfreeze_status=0
fsfreeze_status=0
if [[ -n $1 ]]; then
    volgrps=$(echo $1 | sed 's/,/ /')
    echo "$(date) : Volumes Groups to Freeze : $volgrps" >> /tmp/cohesity_snap.log
    # if [[ $testing -ne 1 ]]; then
    #     for vgs in $volgrps
    #     do
    #         for ii in $(lsvgfs $vgs)
    #         do
    #             echo "$(date) : Freezing Filesystem: $ii" >> /tmp/cohesity_snap.log
    #             echo "Freezing Filesystem: $ii"
    #             chfs -a freeze=300 $ii
    #             if [[ $? -ne 0 ]]; then
    #                 (( fsfreeze_status+=1 ))
    #                 echo "$(date) : $COHESITY_BACKUP_ENTITY : FileSystem Freeze Failed: $ii"  >> /tmp/cohesity_snap.log
    #                 echo "FileSystem Freeze Failed: $ii"
    #             fi
    #         done
    #     done
    # fi
fi

################
## Freeze Failed
################

if [[ $fsfreeze_status -gt 0 ]]; then

    echo "Freeze Failed. Rolling Back:"
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Freeze Failed. Rolling Back ****" >> /tmp/cohesity_snap.log

    #### Thaw file systems
    
    # if [[ $testing -ne 1 ]]; then
    #     for vgs in $volgrps
    #     do
    #         for ii in $(lsvgfs $vgs)
    #         do
    #             echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing Filesystem: $ii" >> /tmp/cohesity_snap.log
    #             echo "Thawing Filesystem: $ii"
    #             chfs -a freeze=off $ii
    #         done
    #     done
    # fi

    #### Thaw database
    echo "Thawing Database"
	echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing Database" >> /tmp/cohesity_snap.log
    if [[ $testing -ne 1 ]]; then
	    /opt/scripts/ZBACKUP/thaw.sh
    fi

    echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log
    mkdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.failed
	rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX >> /tmp/cohesity_snap.log 2>&1
    rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
    exit 2
else

    ####################
    ## Freeze Successful
    ####################

    #### create snapshots
    echo "$(date) : $COHESITY_BACKUP_ENTITY : FileSystem Freeze Successful" >> /tmp/cohesity_snap.log
    echo "FileSystem Freeze Successful."
	echo "$(date) : $COHESITY_BACKUP_ENTITY : Snapshotting Pure Volumes" >> /tmp/cohesity_snap.log
	echo "Running purevol snap."
	echo "/usr/bin/ssh ${PRIVKEY_PATH} ${PURE_USER}@${PURE_ARRAY} purevol snap --suffix ${COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX} ${PURE_SRC_LUNS}" > /tmp/cohesity_snap.log 2>&1
	/usr/bin/ssh ${PRIVKEY_PATH} ${PURE_USER}@${PURE_ARRAY} "purevol snap --suffix ${COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX} ${PURE_SRC_LUNS}" 
  	if [[ $? -eq 0 ]]; then
    	echo "$(date) : $COHESITY_BACKUP_ENTITY : Pure Volume Snaps Successful" >> /tmp/cohesity_snap.log
    	echo "Pure Volume Snaps Successful" 
        snap_status=0
  	else
    	echo "$(date) : $COHESITY_BACKUP_ENTITY : Pure Volume Snap Failed" >> /tmp/cohesity_snap.log
    	echo "Pure Volume Snap Failed" 
		snap_status=5
  	fi

    #### Thaw database
	echo "Thawing Database"
	echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing Database" >> /tmp/cohesity_snap.log

    if [[ $testing -ne 1 ]]; then
        /opt/scripts/ZBACKUP/thaw.sh
    fi

    #### Thaw file systems
    # if [[ $testing -ne 1 ]]; then
    #     for vgs in $volgrps
    #     do
    #         for ii in $(lsvgfs $vgs)
    #         do
    #             echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing Filesystem: $ii" >> /tmp/cohesity_snap.log
    #             echo "Thawing Filesystem: $ii"
    #             chfs -a freeze=off $ii
    #         done
    #     done
    # fi

	# echo "Removing Lock: rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX"
    # echo "Removing Lock  /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY. Exiting"
    rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
    if [[ $snap_status -eq 0 ]]; then
        rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX >> /tmp/cohesity_snap.log 2>&1
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed Successfully" >> /tmp/cohesity_snap.log
    else
        mkdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.failed
        rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX >> /tmp/cohesity_snap.log 2>&1
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log
    fi
    echo "" >> /tmp/cohesity_snap.log
    exit $snap_status
fi

exit 0
