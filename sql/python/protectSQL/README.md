# Protect SQL Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script protects SQL.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/python/protectSQL/protectSQL.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectSQL.py
# end download commands
```

## Components

* [protectSQL.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectSQL/protectSQL.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

Protect two SQL servers:

```bash
./protectSQL.py -v mycluster \
                -u myuser \
                -d mydomain.net \
                -j 'My Backup Job' \
                -sn myserver1.mydomain.net \
                -sn myserver2.mydomain.net
```

Protect a SQL Instance:

```bash
./protectSQL.py -v mycluster \
                -u myuser \
                -d mydomain.net \
                -j 'My Backup Job' \
                -sn myserver1.mydomain.net \
                -in MSSQLSERVER
```

Protect a SQL Database:

```bash
./protectSQL.py -v mycluster \
                -u myuser \
                -d mydomain.net \
                -j 'My Backup Job' \
                -sn myserver1.mydomain.net \
                -in MSSQLSERVER \
                -dn mydb
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

## Required Parameters

* -j, --jobname: name of the job to add the server to

## Selection Parameters

* -sn, --servername: (optional) name of server to add to the job (use multiple times for multiple)
* -sl, --serverlist: (optional) list of server names in a text file
* -in, --instancename: (optional) instance name to protect (default is all instances)
* -dn, --dbname: (optional) name of server to add to the job (use multiple times for multiple)
* -dl, --dblist: (optional) list of server names in a text file
* -o, --instancesonly: (optional) protect current instances (future new instances will not be protected)
* -so, --systemdbsonly: (optional) only protect system DBs
* -ud, --unprotecteddbs: (optional) protect unprotected DBs
* -a, --alldbs: (optional) protect all current databases (future new database will not be protected)
* -r, --replace: (optional) replace existing selections

## New Job Parameters

* -b, --backuptype: (optional) File, Volume or VDI (default is File)
* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
* -z, --paused: (optional) pause future runs

## Optional Parameters

* -s, --showunprotecteddbs: (optional) show unprotected DBs on the specified servers and exit
* -n, --numstreams: (optional) number of backup streams (default is 3)
* -l, --logstreams: (optional) number of log backup streams (default is 3)
* -wc, --withclause: (optional) with clause (e.g. 'WITH Compression')
* -lc, --logclause: (optional) log with clause (e.g. 'WITH MAXTRANSFERSIZE = 4194304, BUFFERCOUNT = 64, COMPRESSION')
* -ssd, --sourcesidededuplication: (optional) use source side deduplication
