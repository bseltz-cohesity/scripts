# Cohesity REST API Python Example - Restore Oracle Database

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an Oracle restore using Python.

## Components

* restoreOracle.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/python/restoreOracle/restoreOracle.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x restoreOracle.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./restoreOracle.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -ss oracleprod.mydomain.net \
                   -ts oracledev.mydomain.net \
                   -sd proddb \
                   -td resdb \
                   -oh /home/oracle/app/oracle/product/11.2.0/dbhome_1 \
                   -ob /home/oracle/app/oracle \
                   -od /home/oracle/app/oracle/oradata/resdb
                   -l -w
```

The script takes the following parameters:

* -v, --vip: Cohesity cluster name or IP
* -u, --username: Cohesity Username
* -d, --domain: Cohesity User Domain
* -ss, --sourceserver: name of source oracle server
* -sd, --sourcedb: name of source oracle DB
* -ts, --targetserver: name of target oracle server
* -td, --targetdb: name of target oracle DB
* -oh, --oraclehome: oracle home path on target
* -ob, --oraclebase: oracle base path on target
* -od, --oracledata: oracle data path on target
* -lt, --logtime: point in time to replay the logs to
* -l, --latest: replay logs to latest available point in time
* -o, --overwrite: overwrite existing database
* -n, --norecovery: leave database in no recovery mode
* -w, --wait: wait for completion

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-l** parameter.

Or, if you want to replay logs to a specific point in time, use the **-lt** parameter and specify a date and time in military format like so:

```powershell
-lt '2019-01-20 23:47:02'
```
