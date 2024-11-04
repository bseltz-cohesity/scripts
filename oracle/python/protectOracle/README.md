# Cohesity REST API Python Example - Protect Oracle

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script protects Oracle databases.

## Components

* [protectOracle.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/protectOracle/protectOracle.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/protectOracle/protectOracle.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
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
                   -sn myserver.mydomain.net \
                   -dn mydb
```

```bash
# add all databases on a server to an existing protection job
./protectOracle.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -jn 'My Job' \
                   -sn myserver.mydomain.net
```

```bash
# add one database on a server to a new protection job
./protectOracle.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -p 'My Policy' \
                   -jn 'My Job' \
                   -tz 'America/New_York' \
                   -sn myserver.mydomain.net \
                   -dn mydb
```

```bash
# add all databases on a server to a new protection job
./protectOracle.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -p 'My Policy' \
                   -jn 'My Job' \
                   -tz 'America/New_York' \
                   -sn myserver.mydomain.net
```

```bash
# specify backup node, number of channels, days to delete logs
./protectOracle.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -j 'My Job' \
                   -sn myserver.mydomain.net \
                   -dn mydb \
                   -cn myserver.mydomain.net \
                   -ch 2 \
                   -l 1
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -n, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Selection Parameters

* -sn, --servername: (optional) name of oracle server to protect (repeat for multiple)
* -sl, --serverlist: (optional) text file of oracle servers to protect (one per line)
* -dn, --dbname: (optional) name of database to protect (repeat for multiple, all DBs if omitted)
* -dl, --dblist: (optional) text file of databases to protect (one per line)
* -jn, --jobname: name of protection job
* -pm, --persistmounts: (optional) persist mount points
* -l, --deletelogdays: (optional) delete logs after X days (default is none)
* -lh --deleteloghours: (optional) delete logs after X hours (default is none)
* -ch, --channels: (optional)  number of channels (default is auto)
* -cn, --channelnode: (optional) RAC node to protect (repeat for multiple)
* -cp, --channelport: (optional) channel port (default is 1521)

## New Job Parameters

* -p, --policyname: (optional) name of protection policy (required if job doesn't already exist)
* -st, --starttime: (optional) e.g. '21:00' (default is 20:00)
* -tz, --timezone:(optional) e.g. 'America/Los_Angeles' (default is America/New_York)
* -is, --incrementalsla: (optional) default is 60
* -fs, --fullsla: (optional) default is 120
* -sd, --storagedomain: (optional) default is DefaultStorageDomain
* -z, --paused: (optional) pause future runs
