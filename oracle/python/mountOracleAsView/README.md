# Mount an Oracle DB as a View using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script mounts an Oracle DB backup as a Cohesity View

## Components

* [mountOracleAsView.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/mountOracleAsView/mountOracleAsView.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/mountOracleAsView/mountOracleAsView.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x mountOracleAsView.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./mountOracleAsView.py -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -ss oracleprod.mydomain.net \
                       -ts oracledev.mydomain.net \
                       -sd proddb \
                       -n myview \
                       -l -w
```

## Authentication Parameters

* -v, --vip: (optional) name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password of API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to

## Other Parameters

* -ss, --sourceserver: name of source oracle server
* -sd, --sourcedb: name of source oracle DB
* -ts, --targetserver: (optional) name of target oracle server (default is sourceserver)
* -n, --viewname: (optional) name of target view (default's to sourcedb name)
* -lt, --logtime: (optional) point in time to replay the logs to
* -l, --latest: (optional) replay logs to latest available point in time
* -cc, --channelcount: (optional) number of mounts to create on target server
* -w, --wait: (optional) wait for completion

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-l** parameter.

Or, if you want to replay logs to a specific point in time, use the **-lt** parameter and specify a date and time in military format like so:

```bash
-lt '2019-01-20 23:47:02'
```
