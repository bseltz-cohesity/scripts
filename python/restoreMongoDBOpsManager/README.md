# Restore a MongoDB Ops Manager Cluster Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script restores a MongoDB Ops Manager Cluster.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreMongoDBOpsManager/restoreMongoDBOpsManager.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreMongoDBOpsManager.py
# end download commands
```

## Components

* [restoreMongoDBOpsManager.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreMongoDBOpsManager/restoreMongoDBOpsManager.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To restore a cluster to the original location:

```bash
./restoreMongoDBOpsManager.py -v mycluster \
                              -u myusername \
                              -d mydomain.net \
                              -s myopsmanager1.mydomain.net \
                              -n mycluster1 \
                              -l \
                              -w
```

To restore a cluster to a new location:

```bash
./restoreMongoDBOpsManager.py -v mycluster \
                              -u myusername \
                              -d mydomain.net \
                              -s myopsmanager1.mydomain.net \
                              -n mycluster1 \
                              -to 'myopsmanager2.mydomain.net/organization 0/project 0/mycluster1' \
                              -l \
                              -w
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

* -s, --sourcename: name of protection source to restore from
* -n, --sourceclustername: name of source cluster restore
* -to, --targetobject: (optional) target 'sourcename/orgname/projectname/clustername'
* -lt, --logtime: (optional) Point in time to replay the logs to during the restore (e.g. '2026-02-15 22:31:05')
* -l, --latesst: (optional) Replay the logs to the latest available log backup date
* -sd, --stagingdirectory: (optional) staging path for log recovery (default is /tmp)
* -ss, --sleeptimeseconds: (optional) wait for recovery to complete (default is 30)
* -w, --wait: (optional) Wait for the restore to complete and report end status (e.g. kSuccess)

## Point in Time Recovery

By default (if both **--latest** and **--logtime** are omitted), the latest full/incremental snapshot time will be used for the restore.

If you want to replay the logs to the very latest available point in time, use the **--latest** parameter, or if you want to replay logs to a specific point in time, use the **--logtime** parameter and specify a date and time in military format like so:

```bash
--logtime '2019-01-20 23:47:02'
```

Note that when the --logtime parameter is used with clusters where no log backups exist, the full/incremental backup that occurred at or before the specified log time will be used. Also note that if a logtime is specified that is newer than the latest log backup, the latest log backup time will be used.
