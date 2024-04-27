# List Protection Jobs using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script lists protection jobs.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/jobList/jobList.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x jobList.py
# end download commands
```

## Components

* [jobList.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/jobList/jobList.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./jobList.ps1 -v mycluster \
              -u myuser \
              -d mydomain.net \
              -e vmware
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -s, --storagedomain: (optional) filter by storage domain (e.g. DefaultStorageDomain)
* -e, --environment: (optional) filter by environment (e.g. GenericNAS)
* -p, --paused: (optional) show only paused jobs
