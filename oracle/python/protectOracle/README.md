# Cohesity REST API Python Example - Protect Oracle

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script protects Oracle databases.

## Components

* protectOracle.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/python/protectOracle/protectOracle.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x protectOracle.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# add one database to an existing protection job
./protectOracle.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -j 'My Job' \
                   -s myserver.mydomain.net \
                   -db mydb
```

```bash
# add all databases on a server to an existing protection job
./protectOracle.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -j 'My Job' \
                   -s myserver.mydomain.net
```

```bash
# add one database on a server to a new protection job
./protectOracle.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -p 'My Policy' \
                   -j 'My Job' \
                   -z 'America/New_York' \
                   -s myserver.mydomain.net \
                   -db mydb
```

```bash
# add all databases on a server to a new protection job
./protectOracle.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -p 'My Policy' \
                   -j 'My Job' \
                   -z 'America/New_York' \
                   -s myserver.mydomain.net
```

## Authentication Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password of API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to

## Other Parameters

* -s, --servername: name of source oracle server
* -db, --dbname: name of oracle DB (optional: default is all databases)
* -j, --jobname: name of protection job
* -p, --policyname: name of protection policy (optional: only required if job doesn't already exist)
* -t, --starttime: e.g. '21:00' (optional: default is 20:00)
* -z, --timezone: e.g. 'America/Los_Angeles' (optional: default is America/New_York)
* -is, --incrementalsla: (optional: default is 60)
* -fs, --fullsla: (optional: default is 120)
* -sd, --storagedomain: (optional) default is DefaultStorageDomain)
* -l, --deletelogdays: (optional) delete logs after X days (default is none)
* -pause, --pause: (optional) pause future runs
* -np, --nopersistmounts: (optional) do not persist mount points (default is to persist)
* -pm, --persistmounts: (optional) re-enable persist mount points (if it was previously disabled)
