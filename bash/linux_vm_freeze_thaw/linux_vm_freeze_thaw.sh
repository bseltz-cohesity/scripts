#!/bin/bash

# settings
TESTING=0
FREEZE_CMD="/bin/sudo /my/freeze/command"
THAW_CMD="/bin/sudo /my/thaw/command"

if [[ $1 == "freeze" ]]
then

    echo "This section is executed before the VM snapshot is created"
    
    if [[ $TESTING -eq 1 ]]; then
        echo "$(date) : Test Mode (no freeze)" >> /tmp/cohesity_snap.log
        freeze_status=0
    else
        echo "$(date) : Performing freeze" >> /tmp/cohesity_snap.log
        ${FREEZE_CMD}
        freeze_status=$?
    fi
    if [[ $freeze_status -ne 0 ]]; then
        echo "$(date) : Freeze failed with Error $freeze_status ****" >> /tmp/cohesity_snap.log
        exit 1
    fi

elif [[ $1 == "freezeFail" ]]
then

    echo "This section is executed when a problem occurs during snapshot creation and cleanup is needed since thaw is not executed"

    if [[ $TESTING -eq 1 ]]; then
        echo "$(date) : Test Mode (no thaw)" >> /tmp/cohesity_snap.log
    else
        echo "$(date) : Performing thaw" >> /tmp/cohesity_snap.log
        ${THAW_CMD}
    fi

elif [[ $1 == "thaw" ]]
then

    echo "This section is executed after the snapshot has been created"

    if [[ $TESTING -eq 1 ]]; then
        echo "$(date) : Test Mode (no thaw)" >> /tmp/cohesity_snap.log
    else
        echo "$(date) : Performing thaw" >> /tmp/cohesity_snap.log
        ${THAW_CMD}
    fi

else

    echo "Usage: `/bin/basename $0` [ freeze | freezeFail | thaw ]"
    echo "$(date) : I got bad syntax" >> /tmp/cohesity_snap.log
    exit 1

fi
