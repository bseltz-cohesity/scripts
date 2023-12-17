# Refresh a Protection Source using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script refreshes a protection source.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/refreshSource/refreshSource.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x refreshSource.py
# end download commands
```

## Components

* [refreshSource.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/refreshSource/refreshSource.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./refreshSource.ps1 -v mycluster \
                    -u myuser \
                    -d mydomain.net \
                    -n myserver1.mydomain.net
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -n, --sourcename: name of protection source to refresh (repeat for multiple sources)
