#!/bin/bash

##########################################################################################
##
## Last updated: 2026.04.14 - Brian Seltzer @ Cohesity
##
##########################################################################################

# parameters
SCRIPT_VERSION="2026-04-14"
SNAPPG=0
while getopts "t:i:e:v:" flag
    do
        case "${flag}" in
            t) TESTING=${OPTARG};;
            i) EPIC_INSTANCE=${OPTARG};;
            e) EPIC_USER=${OPTARG};;
            v) VOL_GROUPS=${OPTARG};;
            *) echo "invalid parameter"; exit 1;;
        esac
    done

# Get Epic user from command line arguments or use default user
if [ -z "${EPIC_USER}" ]
then
    EPIC_USER="epicadm"
fi

# Get test mode from command line arguments
if [ -z "${TESTING}" ]
then
    TESTING=0
fi

# Epic freeze/thaw commands
FREEZE_CMD="/bin/sudo -u $EPIC_USER /epic/$EPIC_INSTANCE/bin/instfreeze"
THAW_CMD="/bin/sudo -u $EPIC_USER /epic/$EPIC_INSTANCE/bin/instthaw"

# OS detection (linux or AIX)
OS=`uname`

# Report used args
echo "args:"
echo "    TESTING = $TESTING ::"
echo "    EPIC_USER = $EPIC_USER ::"
echo "    EPIC_INSTANCE = $EPIC_INSTANCE ::"
echo "    PURE_SRC_PGROUP = $PURE_SRC_PGROUP ::"
echo "    OS = $OS ::"
echo "    VOL_GROUPS = $VOL_GROUPS ::"

# Start logging
if [[ ! -e /tmp/cohesity_snap.log ]]; then
    touch /tmp/cohesity_snap.log
fi
echo "################# Cohesity Freeze Script Starting ###############"
echo "$(date) : $COHESITY_BACKUP_ENTITY : Freeze script version $SCRIPT_VERSION Started ::"
echo "COHESITY_BACKUP_ENTITY:$COHESITY_BACKUP_ENTITY ::" 
echo "COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX:$COHESITY_BACKUP_GROUP_SNAPSHOT_SUFFIX ::"

# Try to take leader role
mkdirstatus=1
if [[ ! -e /tmp/$COHESITY_JOB_ID.leader ]]; then
    mkdir /tmp/$COHESITY_JOB_ID.leader
    mkdirstatus=$?
    mkdir /tmp/$COHESITY_JOB_ID.running
fi

# Only freeze if am I the leader
if [[ $mkdirstatus -eq 0 ]]; then
    echo "" >> /tmp/cohesity_snap.log
    echo "################# Cohesity Freeze Script Starting ###############" >> /tmp/cohesity_snap.log
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Freeze script started with PID $$" >> /tmp/cohesity_snap.log
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Leader is $COHESITY_BACKUP_ENTITY" >> /tmp/cohesity_snap.log
    
    echo "---- I am the leader ---- ::"
    # make leader marker
    mkdir -p /tmp/$COHESITY_JOB_ID.leader/$COHESITY_BACKUP_ENTITY
    
    # Freeze Database
    if [[ $TESTING -eq 1 ]]; then
        freeze_status=0
        fsfreeze_status=0
    else
        echo "Freezing Database ::"
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Freezing Database" >> /tmp/cohesity_snap.log
        ${FREEZE_CMD}
        freeze_status=$?
    fi

    if [[ $freeze_status -ne 0 ]]; then
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Database Freeze Failed: $freeze_status"  >> /tmp/cohesity_snap.log
        echo "Database Freeze Failed: $freeze_status"
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log
        echo "!!!!!!!!!!!! Cohesity Freeze Script Failed !!!!!!!!!!!!"
        mkdir -p /tmp/COHESITY_JOB_ID.failed
        rm -rf /tmp/$COHESITY_JOB_ID.running
        exit 1
    else
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Database Freeze Successful" >> /tmp/cohesity_snap.log
    fi

    # Freeze AIX File Systems
    # typeset -i fsfreeze_status=0
    fsfreeze_status=0
    if [[ -n $VOL_GROUPS ]] && [[ $TESTING -eq 0 ]] && [[ $OS == "AIX" ]]; then
        volgrps=$(echo $VOL_GROUPS | sed 's/,/ /g')
        echo "$(date) : Volumes Groups to Freeze : $volgrps" >> /tmp/cohesity_snap.log
        for vgs in $volgrps
        do
            for ii in $(lsvgfs $vgs)
            do
                echo "$(date) : Freezing Filesystem: $ii" >> /tmp/cohesity_snap.log
                echo "Freezing Filesystem: $ii ::"
                chfs -a freeze=300 $ii
                if [[ $? -ne 0 ]]; then
                    (( fsfreeze_status+=1 ))
                    echo "$(date) : $COHESITY_BACKUP_ENTITY : FileSystem Freeze Failed: $ii"  >> /tmp/cohesity_snap.log
                    echo "FileSystem Freeze Failed: $ii ::"
                fi
            done
        done
    fi

    # Freeze Failed - let's thaw
    if [[ $fsfreeze_status -gt 0 ]]; then
        volgrps=$(echo $VOL_GROUPS | sed 's/,/ /g')
        echo "Freeze Failed. Rolling Back: ::"
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Freeze Failed. Rolling Back ****" >> /tmp/cohesity_snap.log

        # Thaw AIX file systems
        if [[ $TESTING -ne 1 ]]; then
            for vgs in $volgrps
            do
                for ii in $(lsvgfs $vgs)
                do
                    echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing Filesystem: $ii" >> /tmp/cohesity_snap.log
                    echo "Thawing Filesystem: $ii ::"
                    chfs -a freeze=off $ii
                done
            done
        fi

        # Thaw database
        echo "Thawing Database ::"
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing Database" >> /tmp/cohesity_snap.log
        if [[ $TESTING -ne 1 ]]; then
            ${THAW_CMD}
        fi

        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log
        echo "!!!!!!!!!!!! Cohesity Freeze Script Failed !!!!!!!!!!!!"
        mkdir -p /tmp/COHESITY_JOB_ID.failed
        rm -rf /tmp/$COHESITY_JOB_ID.running
        exit 2
    else
        # Freeze Successful
        echo "$(date) : $COHESITY_BACKUP_ENTITY : FileSystem Freeze Successful" >> /tmp/cohesity_snap.log
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed Successfully" >> /tmp/cohesity_snap.log
        echo "################# Cohesity Freeze Script Completed Successfully ###############"
        # mkdir -p /tmp/$COHESITY_JOB_ID.frozen.$COHESITY_BACKUP_ENTITY
        rm -rf /tmp/COHESITY_JOB_ID.failed
        rm -rf /tmp/$COHESITY_JOB_ID.running
        exit 0
    fi
else
    # I'm not the leader, wait for leader
    echo "Waiting for leader $LEADER to complete the freeze ::"
    while [[ -e /tmp/$COHESITY_JOB_ID.running ]]; do
        sleep 1
        if [[ -e /tmp/$COHESITY_JOB_ID.failed ]]; then
            rm -rf /tmp/$COHESITY_JOB_ID.$COHESITY_BACKUP_ENTITY
            echo "!!!!!!!!!!!! Cohesity Freeze Script Failed !!!!!!!!!!!!"
            exit 1
        fi
    done
    if [[ -e /tmp/$COHESITY_JOB_ID.failed ]]; then
        rm -rf /tmp/$COHESITY_JOB_ID.$COHESITY_BACKUP_ENTITY
        echo "!!!!!!!!!!!! Cohesity Freeze Script Failed !!!!!!!!!!!!"
        exit 1
    fi
    mkdir -p /tmp/$COHESITY_JOB_ID.frozen/$COHESITY_BACKUP_ENTITY
    echo "################# Cohesity Freeze Script Completed Successfully ###############"
    exit 0
fi
