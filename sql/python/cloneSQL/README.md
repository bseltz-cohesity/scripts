# Clone a SQL DB Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script clones a Microsoft SQL Server database from a Cohesity backup to a target SQL Server instance, with optional point-in-time log replay.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/sql/python/cloneSQL/cloneSQL.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x cloneSQL.py
# end download commands
```

## Components

* cloneSQL.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To clone a database to a different server/instance with a new name:

```bash
./cloneSQL.py -v mycluster \
              -u myuser \
              -d mydomain.net \
              -ss sql1.mydomain.net \
              -sd ProdDB \
              -ts sql2.mydomain.net \\
              -td CloneDB
```

To clone with a point-in-time log replay and wait for completion:

```bash
./cloneSQL.py -v mycluster \
              -u myuser \
              -d mydomain.net \
              -ss sql1.mydomain.net\
              -sd ProdDB \
              -ts sql2.mydomain.net \
              -td CloneDB \
              -lt '2019-09-29 17:51:01' \
              -w
```

To clone from the very latest available log point:

```bash
./cloneSQL.py -v mycluster \
              -u myuser \
              -d mydomain.net \
              -ss sql1.mydomain.net \
              -sd ProdDB \
              -ts sql2.mydomain.net \
              -td CloneDB \
              -l
```

To connect through Helios or MCM:

```bash
./cloneSQL.py -v helios.cohesity.com \
              -u myuser \
              -d mydomain.net \
              -c myclustername \
              -ss sql1.mydomain.net \
              -sd ProdDB \
              -ts sql2.mydomain.net \
              -td CloneDB
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) org to impersonate
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -ss, --sourceserver: (required) protection source where the DB was backed up
* -sd, --sourcedb: (required) name of the source DB to clone (accepts instance/dbname format)
* -ts, --targetserver: (optional) server to attach the clone DB to (defaults to sourceserver)
* -td, --targetdb: (optional) desired name of the clone DB (defaults to sourcedb)
* -ti, --targetinstance: (optional) SQL instance name on the target server (default is MSSQLSERVER)
* -lt, --logtime: (optional) point in time log replay, e.g. '2019-09-29 17:51:01'
* -nl, --nologs: (optional) skip log replay even if a valid log time is found
* -l, --latest: (optional) replay logs to the very latest available point in time
* -w, --wait: (optional) wait for the clone task to complete
* -st, --sleeptime: (optional) seconds to wait between status checks while waiting (default is 15)
* -dbg, --dbg: (optional) write the clone task JSON to clone-sql.json and exit without executing
