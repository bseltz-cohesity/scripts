# Get Cluster and Node Information Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script collects cluster and node information.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/clusterInfo/clusterInfo.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x clusterInfo.py
# end download commands
```

## Components

* [clusterInfo.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/clusterInfo/clusterInfo.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./clusterInfo.py -v mycluster \
                  -u myusername \
                  -d mydomain.net \
                  -pwd swordfish \
                  -t myuser@mydomain.net \
                  -t anotheruser@mydomain.net \
                  -s 192.168.1.95 \
                  -f backupreport@mydomain.net \
                  -l
```

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

## Other Parameters

* -l, --listgflags: (optional) list gflags
* -of, --outfolder: (optional) default is '.'
