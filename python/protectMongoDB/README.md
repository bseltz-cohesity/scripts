# Protect MongoDB using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script protects MongoDB sources, databases and collections.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectMongoDB/protectMongoDB.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectMongoDB.py
# end download commands
```

## Components

* [protectMongoDB.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectMongoDB/protectMongoDB.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To protect autoprotect an entire source:

```bash
./protectMongoDB.py -v mycluster \
                    -u myusername \
                    -d mydomain.net \
                    -s mongo1.mydomain.net:27017 \
                    -j 'mongo backup'
```

To protect specific databases:

```bash
./protectMongoDB.py -v mycluster \
                    -u myusername \
                    -d mydomain.net \
                    -s mongo1.mydomain.net:27017 \
                    -j 'mongo backup' \
                    -n database1 \
                    -n database 2
```

To protect specific collections:

```bash
./protectMongoDB.py -v mycluster \
                    -u myusername \
                    -d mydomain.net \
                    -s mongo1.mydomain.net:27017 \
                    -j 'mongo backup' \
                    -n database1.collection1 \
                    -n database2.collection2
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: name of the protection job
* -s, --sourcename: name of registered MongoDB protection source
* -n, --objectname: (optional) one or more database or database.collection names (repeat for multiple)
* -l, --objectlist: (optional) text file of database or database.collection names (one per line)
* -ex, --exclude: (optional) autoprotect the source and exclude objects in --objectname and --objectlist

## New Job Parameters

* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -z, --paused: (optional) pause new protection group
* -q, --qospolicy: (optional) kBackupHDD, kBackupSSD, or kBackupAll (default is kBackupHDD)
* -streams, --streams: (optional) number of concurrent streams (default is 16)
