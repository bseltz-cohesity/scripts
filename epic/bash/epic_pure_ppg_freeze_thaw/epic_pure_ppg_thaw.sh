#!/bin/bash

##########################################################################################
##
## Last updated: 2026.04.09 - Brian Seltzer @ Cohesity
##
##########################################################################################

# parameters
SCRIPT_VERSION="2026-04-14"
while getopts "t:i:e:v:l:" flag
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

# Epic thaw command
THAW_CMD="/bin/sudo -u $EPIC_USER /epic/$EPIC_INSTANCE/bin/instthaw"

# OS detection (linux or AIX)
OS=`uname`

# Report used args
echo "args:"
echo "    TESTING = ${TESTING} ::"
echo "    EPIC_USER = ${EPIC_USER} ::"
echo "    EPIC_INSTANCE = ${EPIC_INSTANCE} ::"
echo "    LEADER = ${LEADER} ::"
echo "    OS = ${OS} ::"
echo "    VOL_GROUPS = ${VOL_GROUPS} ::"

# Start logging
if [[ ! -e /tmp/cohesity_snap.log ]]; then
    touch /tmp/cohesity_snap.log
fi
echo "################# Cohesity Thaw Script Starting ###############"
echo "$(date) : $COHESITY_BACKUP_ENTITY : Thaw script version $SCRIPT_VERSION Started"
echo "COHESITY_BACKUP_ENTITY:$COHESITY_BACKUP_ENTITY ::" 
echo "COHESITY_BACKUP_VOLUME_SNAPSHOT_SUFFIX:$COHESITY_BACKUP_GROUP_SNAPSHOT_SUFFIX ::" 

thaw_status=0

LEADER=$(ls /tmp/$COHESITY_JOB_ID.leader/)

if [[ "$LEADER" == "$COHESITY_BACKUP_ENTITY" ]]; then

    # echo "" >> /tmp/cohesity_snap.log
    echo "################# Cohesity Thaw Script Starting ###############" >> /tmp/cohesity_snap.log
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Thaw script started with PID $$" >> /tmp/cohesity_snap.log
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Leader is $COHESITY_BACKUP_ENTITY" >> /tmp/cohesity_snap.log
    echo "---- I am the leader ---- ::"

    # wait for non-leaders
    FOLLOWERS=$(ls /tmp/$COHESITY_JOB_ID.frozen/)
    while [[ "$FOLLOWERS" != '' ]]; do
        sleep 1
        FOLLOWERS=$(ls /tmp/$COHESITY_JOB_ID.frozen/)
    done

    # Thaw AIX file systems
    if [[ -n $VOL_GROUPS ]] && [[ $TESTING -eq 0 ]] && [[ $OS == "AIX" ]]; then
        echo "Thawing File Systems"
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing file systems" >> /tmp/cohesity_snap.log
        if [[ -n $VOL_GROUPS ]] && [[ $TESTING -eq 0 ]] && [[ $OS == "AIX" ]]; then
            volgrps=$(echo $VOL_GROUPS | sed 's/,/ /g')
            echo "$(date) : Volumes Groups to Freeze : $volgrps" >> /tmp/cohesity_snap.log
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
    fi

    # Thaw database
    echo "Thawing Database"
    echo "$(date) : $COHESITY_BACKUP_ENTITY : Thawing Database" >> /tmp/cohesity_snap.log

    if [[ $TESTING -ne 1 ]]; then
        ${THAW_CMD}
        thaw_status=$?
    fi
    # Thaw was successful
    if [[ $thaw_status -eq 0 ]]; then
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed Successfully" >> /tmp/cohesity_snap.log
        echo "################# Cohesity Thaw Script Completed Successfully ###############"
    else
        # Thaw failed
        echo "$(date) : $COHESITY_BACKUP_ENTITY : Script Completed with Error ****" >> /tmp/cohesity_snap.log
        echo "!!!!!!!!!!!! Cohesity Thaw Script Failed !!!!!!!!!!!!"
    fi
    rm -rf /tmp/$COHESITY_JOB_ID.leader
else
    rm -rf /tmp/$COHESITY_JOB_ID.frozen/$COHESITY_BACKUP_ENTITY
    echo "################# Cohesity Thaw Script Completed Successfully ###############"
fi

exit $thaw_status
