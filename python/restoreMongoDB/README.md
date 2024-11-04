# Restore MongoDB using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script script restores MongoDB databases/collections

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreMongoDB/restoreMongoDB.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreMongoDB.py
# end download commands
```

## Components

* [restoreMongoDB.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreMongoDB/restoreMongoDB.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To restore a database/collection and overwrite the original:

```bash
./restoreMongoDB.py -v mycluster \
                    -u myusername \
                    -d mydomain.net \
                    -s mongo1.mydomain.net:27017 \
                    -n customers.notes \
                    -o
                    -w
```

Or to restore to an alternate MongoDB server:

```bash
./restoreMongoDB.py -v mycluster \
                    -u myusername \
                    -d mydomain.net \
                    -s mongo1.mydomain.net:27017 \
                    -t mongodb2.mydomain.net:27017 \
                    -x 'restore' \
                    -w
```

To protect specific collections:

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

* -s, --sourceserver: source server to restore from
* -n, --sourceobject: source database/collection to restore

## Optional Parameters

* -t, --targetserver: (optional) target server to restore to (defaults to source server)
* -dt, --recoverdate: (optional) recover from snapshot on or before this date (e.g. '2022-09-21 23:00:00')
* -streams, --streams: (optional) number of cuncurrency streams (defaul is 16)
* -x, --suffix: (optional) suffix to apply to recovered object name (e.g. 'restore')
* -o, --overwrite: (optional) overwrite existing object
* -w, --wait: (optional) wait for completion and report status
