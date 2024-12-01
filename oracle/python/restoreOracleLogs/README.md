# Restore Oracle Archive Logs Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script performs an restore of Oracle archive logs.

## Components

* [restoreOracleLogs.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/restoreOracleLogs/restoreOracleLogs.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/restoreOracleLogs/restoreOracleLogs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreOracleLogs.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./restoreOracleLogs.py -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -ss oracleprod.mydomain.net \
                       -sd proddb \
                       -p /home/oracle/test
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

## Basic Parameters

* -p, --path: path to restore archive logs (e.g. /home/oracle/test)
* -ss, --sourceserver: Server name where the database was backed up
* -sd, --sourcedb: Original database name
* -ch, --channels: (optional) Number of restore channels
* -cn, --channelnode: (optional) RAC node to use for channels
* -w, --wait: (optional) wait for restore to finish and report result
* -pr, --progress: (optional) display percent complete
* -dbg, --dbg: (optional) output JSON payload for debugging

## Log Range Parameters

* -rt, --rangetype: (optional) lsn, scn, or time (default is lsn)
* -s, --showranges: (optional) show available ranges (of selected range type) and exit
* -st, --starttime: (optional) use when using time range type (e.g. '2024-12-01 21:00:00')
* -et, --endtime: (optional) use when using time range type (e.g. '2024-12-01 23:00:00')
* -sr, --startofrange: (optional) use when using lsn or scn range types (e.g. 1257)
* -er, --endofrange: (optional) use when using lsn or scn range types (e.g. 1259)

## Alternate Destination Parameters

* -ts, --targetserver: (optional) name of target oracle server (default is sourceserver)
* -td, --targetdb: (optional) name of target oracle DB (default is sourcedb)
* -oh, --oraclehome: (optional) oracle home path on target (not required when overwriting original db)
* -ob, --oraclebase: (optional) oracle base path on target (not required when overwriting original db)
