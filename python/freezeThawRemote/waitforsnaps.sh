#!/bin/bash
# python monitoring script location (script host)
SCRIPT_LOCATION=someuser@192.168.1.195
SCRIPT_FILE=./monitorTasks.py

# freeze/thaw script location (backup host)
SCRIPT_CALLBACK=someuser@192.168.1.191
CALLBACK_FILE=./thaw.sh

# Cohesity info
COHESITY_CLUSTER=cluster1
COHESITY_USER=admin

# python script parameters
TIMEOUTSEC=120
MAIL_SERVER=192.168.1.95
SENDTO=me@mydomain.net
SENDFROM=somehost@mydomain.net
KEYSTRING='Getting mapped/changed areas for volume' # pure
# KEYSTRING='Starting directory differ' # netapp

ssh -t $SCRIPT_LOCATION "$SCRIPT_FILE -v $COHESITY_CLUSTER -u $COHESITY_USER -j $COHESITY_JOB_ID -n $COHESITY_JOB_NAME -k '$KEYSTRING' -o $TIMEOUTSEC -c $SCRIPT_CALLBACK -b $CALLBACK_FILE -s $MAIL_SERVER -t $SENDTO -f $SENDFROM"

