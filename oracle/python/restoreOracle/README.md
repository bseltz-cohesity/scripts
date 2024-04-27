# Cohesity REST API Python Example - Restore Oracle Database

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an Oracle restore using Python.

## Components

* [restoreOracle.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/restoreOracle/restoreOracle.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/oracle/python/restoreOracle/restoreOracle.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
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

## Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password of API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -ss, --sourceserver: name of source oracle server
* -sd, --sourcedb: name of source oracle DB
* -ch, --channels: number of restore channels (default is 1)
* -cn, --channelnode: rac node for channels
* -o, --overwrite: overwrite existing database
* -n, --norecovery: leave database in no recovery mode
* -pf, --pfileparameter: example -pf 'param1=value1' -pf tde_configuration="'KEYSTORE_CONFIGURATION=FILE'" -pf wallet_root=+data/MYDB/WALLET (repeat for multiple parameters)
* -sh, --shellvariable: example -sh 'var1=value1' (repeat for multiple variables)

## Point in Time Parameters

* -lt, --logtime: point in time to replay the logs to
* -l, --latest: replay logs to latest available point in time

## Alternate Destination Parameters

* -ts, --targetserver: name of target oracle server (default is sourceserver)
* -td, --targetdb: name of target oracle DB (default is sourcedb)
* -oh, --oraclehome: oracle home path on target
* -ob, --oraclebase: oracle base path on target
* -od, --oracledata: oracle data path on target
* -cf, --controlfile: alternate ctl file path
* -r, --redologpath: alternate redo log path
* -a, --auditpath: alternate audit path
* -dp, --diagpath: alternate diag path
* -f, --frapath: alternate fra path
* -fs, --frasizeMB: alternate fra size in MB
* -b, --bctfile:  alternate bct file path

## Misc Parameters

* -w, --wait: wait for completion

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-l** parameter.

Or, if you want to replay logs to a specific point in time, use the **-lt** parameter and specify a date and time in military format like so:

```bash
-lt '2019-01-20 23:47:02'
```
