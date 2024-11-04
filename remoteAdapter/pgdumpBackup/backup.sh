#!/bin/bash

SCRIPT_VERSION="2024-08-20"

# parameters
while getopts "v:x" flag
    do
        case "${flag}" in
            v) VIEWPATH=${OPTARG};;
            x) UNUSED=${OPTARG};;
            *) echo "invalid parameter"; exit 1;;
        esac
    done

if [ -z "${VIEWPATH}" ]
then
    echo "Usage: -v <view path>"
    exit 1
fi

DBHOST='localhost'
DBPORT=5432
DBUSER='postgres'
DBPASS='postgres'
DBNAME='postgres'
PG_DUMP_CMD=`which pg_dump`

# mount view
if [[ ! -e /mnt/pgdump ]]; then
    sudo mkdir /mnt/pgdump
fi
echo " -- mounting $VIEWPATH"
sudo mount -t nfs -o soft,intr,noatime,retrans=1000,timeo=900,retry=5,rsize=1048576,wsize=1048576,nolock $VIEWPATH /mnt/pgdump/
sudo chmod 777 /mnt/pgdump
if [[ ! -e /mnt/pgdump/postgres ]]; then
    sudo mkdir /mnt/pgdump/postgres
    sudo chmod 777 /mnt/pgdump/postgres
fi

# pgdump backup
touch ~/.pgpass
chmod 0600 ~/.pgpass
echo "$DBHOST:$DBPORT:$DBNAME:$DBUSER:$DBPASS" > ~/.pgpass
echo " -- postgresql backup started"
SECONDS=0
$PG_DUMP_CMD -h $DBHOST -p $DBPORT -U $DBUSER -d postgres -F c -f /mnt/pgdump/postgres/pgbackup.tar.gz
DUMP_STATUS=$?
DURATION_IN_SECONDS=$SECONDS
echo " -- postgresql backup finished in $DURATION_IN_SECONDS seconds with exit code $DUMP_STATUS"
rm ~/.pgpass

# unmount view
echo " -- unmounting $VIEWPATH"
sudo umount /mnt/pgdump
echo " -- script completed"

exit $DUMP_STATUS
