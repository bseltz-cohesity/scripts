#!/bin/bash

####
# Collect db info
###

ask(){
    declare -g $1="$2"
    if [ -z "${!1}" ]; then
        if [[ "$3" == "iris_cli password:" ]]; then
            read -p "$3" -s $1
        else
            read -p "$3" $1
        fi
    fi
}

echo ""
ask IRIS_USER "$1" "iris_cli username:"
ask IRIS_PASS "$2" "iris_cli password:"
echo ""
echo ""

DBHOST=`iris_cli -username=$IRIS_USER -password=$IRIS_PASS custom-reporting db | grep -i ip | awk '{print $4}' | head -1`
DBPORT=27999
DBUSER='reporting_read'
DBPASS=`iris_cli -username=$IRIS_USER -password=$IRIS_PASS custom-reporting db | grep -i password | awk '{print $5}' | head -1`

PG_DUMP_CMD=`which pg_dump`

CLUSTER_NAME=`iris_cli -username=$IRIS_USER -password=$IRIS_PASS cluster info | grep -i "cluster name" | awk '{print $4}'`
CLUSTER_ID=`iris_cli -username=$IRIS_USER -password=$IRIS_PASS cluster info | grep -i "cluster id" | awk '{print $4}'`

CLUSTER_NAME=${CLUSTER_NAME^^}

######
# Create TEMP dir in home_cohesity_data
#####

mkdir -p /home/cohesity/data/dbdump-tmp

#######
# Dump reporting db
######

touch /home/cohesity/.pgpass
chmod 0600 /home/cohesity/.pgpass

echo "$DBHOST:$DBPORT:postgres:$DBUSER:$DBPASS" > /home/cohesity/.pgpass

$PG_DUMP_CMD -h $DBHOST -p $DBPORT -U $DBUSER -d postgres -F c -f /home/cohesity/data/dbdump-tmp/db-$CLUSTER_NAME-$CLUSTER_ID.tar.gz

rm /home/cohesity/.pgpass

######
# Show Output
#####

echo "Export Complete. File can be found: /home/cohesity/data/dbdump-tmp/db-$CLUSTER_NAME-$CLUSTER_ID.tar.gz"
echo ""