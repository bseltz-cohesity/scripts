# Add Global Exclude Paths to Generic NAS Protection Groups Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds/removes entries to the exclude list for all generic NAS protection groups.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/globalExcludePath/globalExcludeNasPath.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x globalExcludeNasPaths.py
# end download commands
```

## Components

* [globalExcludeNasPath.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/globalExcludeNasPath/globalExcludeNasPath.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./globalExcludeNasPath.py -vip mycluster -username myusername -domain mydomain.net -excludepath '/junk'
```

## Parameters

* -vip: Cohesity Cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain of user (defaults to local)
* -excludepath: path to exclude
* -remove: (optional) remove specified path from the exclude list
