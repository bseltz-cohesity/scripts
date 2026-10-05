#!/bin/bash

##########################################################################################
##
## Last updated: 2024.02.28 - Brian Seltzer @ Cohesity
##
##########################################################################################

# example: ./epic_pure_snapper.sh -k /root/.ssh/id_rsa -p puresnap -a 10.12.1.39 -g EpicProtectionGroup26 -i prd

# verify we are NOT running from a Cohesity backup
if [ -z "${COHESITY_BACKUP_ENTITY}" ]
then
    echo "Running epic_pure_snapper version 2024.02.28"
    echo "Running epic_pure_snapper version 2024.02.28" >> /tmp/cohesity_snap.log
else
    echo "*** Exiting - this script should NOT be used as a pre script to a Cohesity protection group! ***"
    echo "*** Exiting - this script should NOT be used as a pre script to a Cohesity protection group! ***" >> /tmp/cohesity_snap.log
    exit 1
fi

# parameters

while getopts "t:k:p:a:g:v:i:e:f" flag
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
COHESITY_BACKUP_ENTITY=$EPIC_INSTANCE
echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Started" >> /tmp/cohesity_snap.log

if [[ ! -e /tmp/cohesity_snap.log ]]; then
    touch /tmp/cohesity_snap.log
fi

echo "" >> /tmp/cohesity_snap.log
echo "################# Backup For $(date) #########################" >> /tmp/cohesity_snap.log

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
    exit 2

else

    #### Freeze Successful
    echo "$(date) : $COHESITY_BACKUP_ENTITY : FileSystem Freeze Successful" >> /tmp/cohesity_snap.log

    #### create ppg snaps
    PURE_SRC_PGROUPS=$(echo $PURE_SRC_PGROUP | sed 's/,/ /g')
    echo "Running purepgroup snap."
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Snapshotting Pure Protection Groups" >> /tmp/cohesity_snap.log
    for pg in $PURE_SRC_PGROUPS
    do
        /usr/bin/ssh -i ${PRIVKEY_PATH} ${PURE_USER}@${PURE_ARRAY} "purepgroup snap --apply-retention --suffix Cohesity-$(date '+%Y-%m-%d-%H-%M-%S') ${pg}"
    done

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
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed Successfully" >> /tmp/cohesity_snap.log
    # Snapshot failed
    else
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log
    fi
    echo "" >> /tmp/cohesity_snap.log
    exit $snap_status
fi

exit 0
