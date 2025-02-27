# Protect Cassandra Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script protects Cassandra databases.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectCassandra/protectCassandra.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectCassandra.py
# end download commands
```

## Components

* [protectCassandra.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectCassandra/protectCassandra.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectCassandra.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -j 'My Backup Job' \
                      -s mycassandra.mydomain.net
```

By default, all regular keyspaces/tables will be autoprotected.

You can specify to protect system keyspaces instead:

```bash
./protectCassandra.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -j 'My Backup Job' \
                      -s mycassandra.mydomain.net \
                      -sk
```

You can protect specific keyspaces and tables:

```bash
./protectCassandra.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -j 'My Backup Job' \
                      -s mycassandra.mydomain.net \
                      -n keyspace1 \
                      -n keyspace2/table1
```

You can exclude keyspaces and tables:

```bash
./protectCassandra.py -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -j 'My Backup Job' \
                      -s mycassandra.mydomain.net \
                      -n keyspace1 \
                      -e keyspace1/table7
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -em --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: name of the job to add the server to
* -s, --sourcename: name of registered Isilon to protect
* -n, --objectname: (optional) protect specific volumes(repeat for multiple volumes)
* -l, --objectlist: (optional) list of volume names in a text file
* -e, --exclude: (optional) file path to exclude (use multiple times for multiple paths)
* -x, --excludelist: (optional) a text file full of exclude file paths
* -sk, --systemkeyspaces: (optional) protect system keyspaces
* -cc, --concurrency: (optional) specify concurrency (default is 16)
* -bw, --bandwidth: (optional) specify bandwidth limit (MB/s)
* -z, --pause: (optional) pause future runs

## New Job Parameters

* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
