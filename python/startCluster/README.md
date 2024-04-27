# Start Cohesity Cluster Services Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script starts the Cohesity cluster services.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/startCluster/startCluster.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x startClsuter.py
# end download commands
```

## Components

* [startCluster.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/startCluster/startCluster.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./startCluster.py -s nodeIp \
                  -u myusername \
                  -d mydomain.net
```

## Parameters

* -s, --server: DNS or IP of a Cohesity node
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
