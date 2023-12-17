# Cohesity REST API Python Example - Instant Oracle Clone

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script demonstrates how to perform an Oracle Clone Attach using Python. The script takes a thin-provisioned clone of the latest backup of an Oracle database and attaches it to an Oracle server.

## Components

* [cloneOracle.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/python/cloneOracle/cloneOracle.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/oracle/python/cloneOracle/cloneOracle.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x cloneOracle.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./cloneOracle.py -v mycluster \
                 -u myuser \
                 -d mydomain.net \
                 -ss oracleprod.mydomain.net \
                 -ts oracledev.mydomain.net \
                 -sd proddb \
                 -td devdb \
                 -oh /home/oracle/app/oracle/product/11.2.0/dbhome_1 \
                 -ob /home/oracle/app/oracle \
                 -w
```

The script takes the following parameters:

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: (optional) active directory domain of user (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password of API key
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -ss, --sourceserver: name of source oracle server
* -sd, --sourcedb: name of source oracle DB
* -ts, --targetserver: (optional) name of target oracle server
* -td, --targetdb: (optional) name of target oracle DB
* -oh, --oraclehome: oracle home path on target
* -ob, --oraclebase: oracle base path on target
* -ch, --channels: (optional) number of restore channels (default is 2)
* -cn, --channelnode: (optional) rac node for channels
* -vlan, --vlan: (optional) VLAN ID to use for restore
* -pf, --pfileparameter: (optional) example -pf 'param1=value1' (repeat for multiple variables)
* -sh, --shellvariable: (optional) example -sh 'var1=value1' (repeat for multiple variables)
* -prescript, --prescript: (optional) script to run before clone operation
* -postscript, --postscript: (optional) args for prescript
* -prescriptargs, --prescriptargs: (optional) script to run after clone operation
* -postscriptargs, --postscriptargs: (optional) args for postscript
* -t, --scripttimeout: (optional) timeout pre/post script execution (default is 900 seconds)
* -lt, --logtime: (optional) point in time to replay the logs to
* -l, --latest: (optional) replay logs to latest available point in time
* -w, --wait: (optional) wait for completion

## Point in Time Recovery

If you want to replay the logs to the very latest available point in time, use the **-l** parameter.

Or, if you want to replay logs to a specific point in time, use the **-lt** parameter and specify a date and time in military format like so:

```bash
-lt '2019-01-20 23:47:02'
```
