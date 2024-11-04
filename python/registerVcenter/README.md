# Register a vCenter Protection Source using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script registers a vCenter protection source.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerVcenter/registerVcenter.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerVcenter.py
# end download commands
```

## Components

* [registerVcenter.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerVcenter/registerVcenter.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerVcenter.ps1 -v mycluster \
                      -u myuser \
                      -d mydomain.net \
                      -n myvcenter.mydomain.net \
                      -vu myuser@vsphere.local \
                      -vp myvcenterpassword
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -n, --vcentername: hostname or IP of vCenter to register
* -vu, --vcenterusername: username for vCenter access
* -vp, --vcenterpassword: (optional) password for vCenter access (will be prompted if omitted)
