#!/bin/bash

# basic settings
TESTING=0
EPIC_INSTANCE='PROD'
EPIC_USER='epic'
FREEZE_CMD="/bin/sudo -u $EPIC_USER /epic/$EPIC_INSTANCE/bin/instfreeze"
THAW_CMD="/bin/sudo -u $EPIC_USER /epic/$EPIC_INSTANCE/bin/instthaw"

# pure safe mode snapshot settings
SNAPPG=0
PURE_SRC_PGROUP='pg1,pg2,pg3'
PRIVKEY_PATH='/root/.ssh/is_rsa'
PURE_USER='puresnap'
PURE_ARRAY='192.168.1.10'

if [[ $1 == "freeze" ]]
then

    echo "This section is executed before the Snapshot is created"
    
    if [[ $TESTING -eq 1 ]]; then
        echo "$(date) : Test Mode (no freeze)" >> /tmp/cohesity_snap.log
        freeze_status=0
    else
        echo "$(date) : Freezing Database" >> /tmp/cohesity_snap.log
        ${FREEZE_CMD}
        freeze_status=$?
    fi
    if [[ $freeze_status -ne 0 ]]; then
        echo "$(date) : Freeze failed with Error $freeze_status ****" >> /tmp/cohesity_snap.log
        exit 1
    fi

    if [[ $TESTING -eq 0 ]]; then
        if [[ $SNAPPG -eq 1 ]]; then
            echo "$(date) : Snapshotting Pure Protection Groups" >> /tmp/cohesity_snap.log
            PURE_SRC_PGROUPS=$(echo $PURE_SRC_PGROUP | sed 's/,/ /g')
            for pg in $PURE_SRC_PGROUPS
            do
                /usr/bin/ssh -i ${PRIVKEY_PATH} ${PURE_USER}@${PURE_ARRAY} "purepgroup snap --apply-retention --suffix Cohesity-$(date '+%Y-%m-%d-%H-%M-%S') ${pg}"
            done
        fi
    fi

elif [[ $1 == "freezeFail" ]]
then

    echo "This section is executed when a problem occurs during snapshot creation and cleanup is needed since thaw is not executed"
    if [[ $TESTING -eq 1 ]]; then
        echo "$(date) : Test Mode (no thaw)" >> /tmp/cohesity_snap.log
    else
        echo "$(date) : Thawing Database" >> /tmp/cohesity_snap.log
        ${THAW_CMD}
    fi

elif [[ $1 == "thaw" ]]
then

    echo "This section is executed when the Snapshot is removed"
    echo "$(date) : Thawing Database" >> /tmp/cohesity_snap.log
    if [[ $TESTING -eq 1 ]]; then
        echo "$(date) : Test Mode (no thaw)" >> /tmp/cohesity_snap.log
    else
        echo "$(date) : Thawing Database" >> /tmp/cohesity_snap.log
        ${THAW_CMD}
    fi

else

    echo "Usage: `/bin/basename $0` [ freeze | freezeFail | thaw ]"
    echo "$(date) : I got bad syntax" >> /tmp/cohesity_snap.log
    exit 1

fi
