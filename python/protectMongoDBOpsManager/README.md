# Protect MongoDB Ops Manager using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script protects MongoDB Ops manager objects.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectMongoDBOpsManager/protectMongoDBOpsManager.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectMongoDBOpsManager.py
# end download commands
```

## Components

* [protectMongoDBOpsManager.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectMongoDBOpsManager/protectMongoDBOpsManager.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To protect autoprotect an entire source:

```bash
./protectMongoDBOpsManager.py -v mycluster \
                              -u myusername \
                              -d mydomain.net \
                              -n 'myopsmanager.mydomain.net:8080' \
                              -j 'mongo backup'
```

To protect specific objects:

```bash
./protectMongoDBOpsManager.py -v mycluster \
                              -u myusername \
                              -d mydomain.net \
                              -n 'myopsmanager.mydomain.net:8080/organization 0/project 0/rs0' \
                              -n 'myopsmanager.mydomain.net:8080/organization 0/project 1' \
                              -ex 'myopsmanager.mydomain.net:8080/organization 0/project 1/rs1' \
                              -ex 'myopsmanager.mydomain.net:8080/organization 0/project 1/rs2' \
                              -j 'mongo backup'
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: name of the protection job
* -n, --objectname: (optional) one or more objects to protect (repeat for multiple)
* -l, --objectlist: (optional) text file of objects to protect (one per line)
* -ex, --exclude: (optional) one or more objects to exclude (repeat for multiple)
* -el, --excludelist: (optional) text file of objects to exclude (one per line)
* -r, --backuprole: (optional) 'SecondaryPreferred', 'PrimaryPreferred' or 'SecondaryOnly' (default is 'SecondaryPreferred')
* -f, --incrementalonfailure: (optional) convert to full on node failure if omitted
* -pn, --preferredbackupnode: (optional) preferred backup node (repeat for multiple)

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
