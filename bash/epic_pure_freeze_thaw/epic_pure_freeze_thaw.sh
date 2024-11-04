#!/bin/bash

##########################################################################################
##
## Last updated: 2023.06.20 - Brian Seltzer @ Cohesity
##
## - change first line to #!/bin/ksh (AIX) or #!/bin/bash (Linux)
## - edit /etc/ssh/sshd_cohfig: MaxStartups 50:30:150 (first number must be 24 or higher) 
## - epic luns must be in pure protection group
## - pass in pre-script parameters (see example below)
## - TESTING=1 means we will not skip freezing, TESTING=0 means we will freeze
##
##########################################################################################
##
## - Version History ----------------------
## - 2023-03-08 - added leader failure flag
## - 2023-03-09 - added failure on no PPG membership, added leader log indicator
## - 2023-07-29 - parameterized arguments and autodetect OS (Linux or AIX)
## - 2023-08-31 - added support for multiple pure protection groups
## - 2023-11-03 - moved make source LUN locks to after snapshot creation
## - 2023-12-07 - added -s to create a PPG snapshot (for safemode support)
## - 2024-02-14 - added version info to output
## - 2024-06-20 - added epic instance to source lun file name
##
##########################################################################################

# example parameters: -t 1 -k /root/.ssh/id_rsa -p puresnap -a 10.12.1.39 -g EpicProtectionGroup26 -i test -v EpicVolGrp1,EpicVolGrp2 -s

# parameters
SCRIPT_VERSION="2024-02-14"
SNAPPG=0
while getopts "t:k:p:a:g:v:i:e:f:s" flag
    do
        case "${flag}" in
            t) TESTING=${OPTARG};;
            k) PRIVKEY_PATH=${OPTARG};;
            p) PURE_USER=${OPTARG};;
            a) PURE_ARRAY=${OPTARG};;
            g) PURE_SRC_PGROUP=${OPTARG};;
            i) EPIC_INSTANCE=${OPTARG};;
            e) EPIC_USER=${OPTARG};;
            v) VOL_GROUPS=${OPTARG};;
            s) SNAPPG=1;;
            *) echo "invalid parameter"; exit 1;;
        esac
    done

if [ -z "${PRIVKEY_PATH}" ] || [ -z "${PURE_USER}" ] || [ -z "${PURE_ARRAY}" ] || [ -z "${PURE_SRC_PGROUP}" ] || [ -z "${EPIC_INSTANCE}" ]
then
    echo "Usage: -k <private key path> -p <pure array> -a <pure username> -g <pure protection group> -i <epic instance> [ -e <epic username> -v <volgroup1>,<volgroup2> -t 1 ]"
    exit 1
fi

if [ -z "${EPIC_USER}" ]
then
    EPIC_USER="epicadm"
fi

if [ -z "${TESTING}" ]
then
    TESTING=0
fi

FREEZE_CMD="/bin/sudo -u $EPIC_USER /epic/$EPIC_INSTANCE/bin/instfreeze"
THAW_CMD="/bin/sudo -u $EPIC_USER /epic/$EPIC_INSTANCE/bin/instthaw"

# OS detection (linux or AIX)
OS=`uname`

echo "args:"
echo "    TESTING = $TESTING ::"
echo "    PRIVKEY_PATH = $PRIVKEY_PATH ::"
echo "    PURE_USER = $PURE_USER ::"
echo "    PURE_ARRAY = $PURE_ARRAY ::"
echo "    PURE_SRC_PGROUP = $PURE_SRC_PGROUP ::"
echo "    EPIC_USER = $EPIC_USER ::"
echo "    EPIC_INSTANCE = $EPIC_INSTANCE ::"
echo "    OS = $OS ::"
echo "    VOL_GROUPS = $VOL_GROUPS ::"

if [[ $OS == "Linux" ]]; then
    echo "I'm running on linux ::"
fi

if [[ $OS == "AIX" ]]; then
    echo "I'm running on AIX ::"
fi

# Start logging
echo "$(date) : $COHESITY_BACKUP_ENTITY : Script version $SCRIPT_VERSION Started"
echo "$(date) : $COHESITY_BACKUP_ENTITY : Script version $SCRIPT_VERSION Started" >> /tmp/cohesity_snap.log

if [[ ! -e /tmp/cohesity_snap.log ]]; then
    touch /tmp/cohesity_snap.log
fi

if [[ ! -e /tmp/cohesity_SRCLUNS-$EPIC_INSTANCE.txt ]]; then
    touch /tmp/cohesity_SRCLUNS-$EPIC_INSTANCE.txt
fi

###################################
## Check if main script already run
###################################

#### If my lock already exists, we're good, exit and perform the backup
if [[ -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY ]]; then
    echo "Found Lock. Main Script Ran Already"
    if [[ -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX-leader ]]; then
        leader=$(ls /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX-leader)
        echo "----- $leader is the leader -----"
    fi
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

##############################
## Assume Leader Role (or not)
##############################

#### Try to take leader role
mkdirstatus=1
if [[ ! -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX ]]; then
    mkdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX 
    mkdirstatus=$?
fi

#### If not the leader, wait for leader then exit and perform the backup
if [[ $mkdirstatus -ne 0 ]]; then
    echo "Snapshot script already running. Waiting for Main Script to complete"
    while [[ -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX ]]; do
        sleep 1
    done
    echo "Done Waiting."
    if [[ -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX-leader ]]; then
        leader=$(ls /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX-leader)
        echo "----- $leader is the leader -----"
    fi
    # fail on leader failed
    if [[ -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.failed ]]; then
        echo "Failing on signal from leader ***"
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Failing on signal from leader" >> /tmp/cohesity_snap.log
        rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
        exit 1
    fi
    # I'm not in the PPG?
    if [[ ! -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY ]]; then
        echo "*** NOT A MEMBER of PURE PROTECTION GROUP ***"
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Not a member of Pure protection group ***"  >> /tmp/cohesity_snap.log
        exit 1
    fi
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed Successfully" >> /tmp/cohesity_snap.log
    rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
    exit 0
fi

#################################################
## I'm the leader, continue to freeze, snap, thaw
#################################################

leader=$(echo "$COHESITY_BACKUP_ENTITY" | tr / -)
mkdir -p /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX-leader/$leader

echo "" >> /tmp/cohesity_snap.log
echo "################# Backup For $(date) #########################" >> /tmp/cohesity_snap.log
echo "COHESITY_BACKUP_ENTITY:$COHESITY_BACKUP_ENTITY" 
echo "COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX:$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX" 
echo "Cohesity Pre Script Starting.\n"
echo "################# Script Leader ########################"
echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Running as Leader" >> /tmp/cohesity_snap.log
echo "$(date) : $COHESITY_BACKUP_ENTITY : Cohesity Pre-Script starting with PID $$" >> /tmp/cohesity_snap.log
echo "$(date) Created Lock /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX" 

#### Get list of volumes in pure protection group
echo "Generating Source LUN File /tmp/cohesity_SRCLUNS-$EPIC_INSTANCE.txt"
if [[ -e /tmp/cohesity_SRCLUNS-$EPIC_INSTANCE.txt ]]; then
    rm -f /tmp/cohesity_SRCLUNS-$EPIC_INSTANCE.txt
fi
PURE_SRC_PGROUPS=$(echo $PURE_SRC_PGROUP | sed 's/,/ /g')
for pg in $PURE_SRC_PGROUPS
do
    /usr/bin/ssh -i ${PRIVKEY_PATH} ${PURE_USER}@${PURE_ARRAY} "purepgroup listobj --type vol ${PURE_SRC_PGROUP}"  >> /tmp/cohesity_SRCLUNS-$EPIC_INSTANCE.txt
    if [[ $? -ne 0 ]]; then
        echo "Obtaining Pure Source LUNs Failed"
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Obtaining Pure Source LUNs Failed ****" >> /tmp/cohesity_snap.log
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log
        mkdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.failed
        rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX >> /tmp/cohesity_snap.log 2>&1
        rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
        exit 4
    fi
done

PURE_SRC_LUNS=$(sed -e :a -e '$!N; s/\n/ /; ta' /tmp/cohesity_SRCLUNS-$EPIC_INSTANCE.txt)
echo "PURE_SOURCE_LUNS: $PURE_SRC_LUNS"

if [[ ! -e /tmp/$COHESITY_JOB_ID ]]; then
    mkdir /tmp/$COHESITY_JOB_ID
    journalStatus=$?
fi

if [[ $journalStatus -ne 0 ]]; then
    echo "Found Current Snapshot Suffix  $COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX in Journal, Exiting."
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed Successfully" >> /tmp/cohesity_snap.log
    exit 0
fi

#### Freeze Database
if [[ $TESTING -eq 1 ]]; then
    freeze_status=0
    fsfreeze_status=0
else
    echo "Freezing Database"
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Freezing Database" >> /tmp/cohesity_snap.log
	${FREEZE_CMD}
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
fi

#### Freeze AIX File Systems
# typeset -i fsfreeze_status=0
fsfreeze_status=0
if [[ -n $VOL_GROUPS ]] && [[ $TESTING -eq 0 ]] && [[ $OS == "AIX" ]]; then
    volgrps=$(echo $VOL_GROUPS | sed 's/,/ /g')
    echo "$(date) : Volumes Groups to Freeze : $volgrps" >> /tmp/cohesity_snap.log
    if [[ $TESTING -ne 1 ]]; then
        for vgs in $volgrps
        do
            for ii in $(lsvgfs $vgs)
            do
                echo "$(date) : Freezing Filesystem: $ii" >> /tmp/cohesity_snap.log
                echo "Freezing Filesystem: $ii"
                chfs -a freeze=300 $ii
                if [[ $? -ne 0 ]]; then
                    (( fsfreeze_status+=1 ))
                    echo "$(date) : $COHESITY_BACKUP_ENTITY : FileSystem Freeze Failed: $ii"  >> /tmp/cohesity_snap.log
                    echo "FileSystem Freeze Failed: $ii"
                fi
            done
        done
    fi
fi

### Freeze Failed
if [[ $fsfreeze_status -gt 0 ]]; then

    echo "Freeze Failed. Rolling Back:"
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Freeze Failed. Rolling Back ****" >> /tmp/cohesity_snap.log

    #### Thaw AIX file systems
    if [[ $TESTING -ne 1 ]]; then
        for vgs in $volgrps
        do
            for ii in $(lsvgfs $vgs)
            do
                echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing Filesystem: $ii" >> /tmp/cohesity_snap.log
                echo "Thawing Filesystem: $ii"
                chfs -a freeze=off $ii
            done
        done
    fi

    #### Thaw database
    echo "Thawing Database"
	echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing Database" >> /tmp/cohesity_snap.log
    if [[ $TESTING -ne 1 ]]; then
	    ${THAW_CMD}
    fi

    echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log
    mkdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.failed
	rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX >> /tmp/cohesity_snap.log 2>&1
    rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
    exit 2
else

    #### Freeze Successful
    echo "$(date) : $COHESITY_BACKUP_ENTITY : FileSystem Freeze Successful" >> /tmp/cohesity_snap.log

    #### create ppg snaps
    if [[ $SNAPPG -eq 1 ]]; then
        echo "Running purepgroup snap."
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Snapshotting Pure Protection Groups" >> /tmp/cohesity_snap.log
        for pg in $PURE_SRC_PGROUPS
        do
            /usr/bin/ssh -i ${PRIVKEY_PATH} ${PURE_USER}@${PURE_ARRAY} "purepgroup snap --apply-retention --suffix Cohesity-$(date '+%Y-%m-%d-%H-%M-%S') ${pg}"
        done
    fi

    #### create volume snapshots
	echo "$(date) : $COHESITY_BACKUP_ENTITY : Snapshotting Pure Volumes" >> /tmp/cohesity_snap.log
	echo "Running purevol snap."
	echo "/usr/bin/ssh -i ${PRIVKEY_PATH} ${PURE_USER}@${PURE_ARRAY} purevol snap --suffix ${COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX} ${PURE_SRC_LUNS}" >> /tmp/cohesity_snap.log 2>&1
	/usr/bin/ssh -i ${PRIVKEY_PATH} ${PURE_USER}@${PURE_ARRAY} "purevol snap --suffix ${COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX} ${PURE_SRC_LUNS}" 
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

    if [[ $TESTING -ne 1 ]]; then
        ${THAW_CMD}
    fi

    #### Thaw AIX file systems
    if [[ -n $VOL_GROUPS ]] && [[ $TESTING -eq 0 ]] && [[ $OS -eq "AIX" ]]; then
        for vgs in $volgrps
        do
            for ii in $(lsvgfs $vgs)
            do
                echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing Filesystem: $ii" >> /tmp/cohesity_snap.log
                echo "Thawing Filesystem: $ii"
                chfs -a freeze=off $ii
            done
        done
    fi

    # Snapshot was successful
    if [[ $snap_status -eq 0 ]]; then

        #### make source LUN locks
        for jj in $PURE_SRC_LUNS
        do
            mkdir -p /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$jj
        done

        rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX >> /tmp/cohesity_snap.log 2>&1
        # I'm not in the PPG (and I'm the leader)
        if [[ ! -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY ]]; then
            echo "*** NOT A MEMBER of PURE PROTECTION GROUP ***"
            echo "$(date) : $COHESITY_BACKUP_ENTITY : Not a member of Pure protection group ***"  >> /tmp/cohesity_snap.log
            exit 1
        fi
        rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed Successfully" >> /tmp/cohesity_snap.log
    # Snapshot failed
    else
        # I'm not in the PPG (and I'm the leader)
        if [[ ! -e /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY ]]; then
            echo "*** NOT A MEMBER of PURE PROTECTION GROUP ***"
            echo "$(date) : $COHESITY_BACKUP_ENTITY : Not a member of Pure protection group ***"  >> /tmp/cohesity_snap.log
        fi
        rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$COHESITY_BACKUP_ENTITY
        mkdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.failed
        rmdir /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX >> /tmp/cohesity_snap.log 2>&1
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log

        #### make source LUN locks
        for jj in $PURE_SRC_LUNS
        do
            mkdir -p /tmp/$COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX.$jj
        done
    fi
    echo "" >> /tmp/cohesity_snap.log
    exit $snap_status
fi

exit 0
