# Protect a New NFS Mount using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script registers a new generic NAS (NFS) mount point and creates a new protection job for it.

## Components

* [protectNewNFSMount.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectNewNFSMount/protectNewNFSMount.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectNewNFSMount.py -v mycluster -u admin -p "My Policy" -m "192.168.1.14:/var/nfs2"
```

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```
