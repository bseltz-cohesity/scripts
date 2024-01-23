#!/bin/bash

EPIC_INSTANCE='PROD'
EPIC_USER='epic'
FREEZE_CMD="/bin/sudo -u $EPIC_USER /epic/$EPIC_INSTANCE/bin/instfreeze"
THAW_CMD="/bin/sudo -u $EPIC_USER /epic/$EPIC_INSTANCE/bin/instthaw"


if [[ $1 == "freeze" ]]
then

    echo "This section is executed before the Snapshot is created"
    echo "$(date) : Freezing Database" >> /tmp/cohesity_snap.log
    ${FREEZE_CMD}
    freeze_status=$?
    if [[ $freeze_status -ne 0 ]]; then
        echo "$(date) : Freeze failed with Error $freeze_status ****" >> /tmp/cohesity_snap.log
    fi

elif [[ $1 == "freezeFail" ]]
then

    echo "This section is executed when a problem occurs during snapshot creation and cleanup is needed since thaw is not executed"
    echo "$(date) : Thawing Database" >> /tmp/cohesity_snap.log
    ${THAW_CMD}

elif [[ $1 == "thaw" ]]
then

    echo "This section is executed when the Snapshot is removed"
    echo "$(date) : Thawing Database" >> /tmp/cohesity_snap.log
    ${THAW_CMD}

else

    echo "Usage: `/bin/basename $0` [ freeze | freezeFail | thaw ]"
    echo "$(date) : I got bad syntax" >> /tmp/cohesity_snap.log
    exit 1

fi
