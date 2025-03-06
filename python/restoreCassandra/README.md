# Restore Cassandra using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script script restores Cassandra keyspaces/tables

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreCassandra/restoreCassandra.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreCassandra.py
# end download commands
```

## Components

* [restoreCassandra.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreCassandra/restoreCassandra.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To restore a keyspace/table and overwrite the original:

```bash
./restoreCassandra.py -v mycluster \
                      -u myusername \
                      -d mydomain.net \
                      -s cassandra1.mydomain.net \
                      -n keyspace1.table1 \
                      -o \
                      -w
```

Or to restore to an alternate Cassandra server:

```bash
./restoreCassandra.py -v mycluster \
                      -u myusername \
                      -d mydomain.net \
                      -s cassandra1.mydomain.net \
                      -n keyspace1.table1 \
                      -t cassandra2.mydomain.net \
                      -w
```

To protect specific tables:

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -org, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Basic Parameters

* -s, --sourcename: source server to restore from
* -n, --objectname: source keyspace/collection to restore

## Optional Parameters

* -t, --targetserver: (optional) target server to restore to (defaults to source server)
* -r, --newname: (optional) rename keyspace/table
* -x, --suffix: (optional) suffix to apply to recovered object name (e.g. 'restore')
* -dt, --recoverdate: (optional) recover from snapshot on or before this date (e.g. '2022-09-21 23:00:00')
* -cc, --concurrency: (optional) number of recovery streams
* -bw, --bandwidth: (optional) limit bandwidth to X MB/s
* -o, --overwrite: (optional) overwrite existing object
* -w, --wait: (optional) wait for completion and report status
