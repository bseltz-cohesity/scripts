# Backup a VM Now using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script registers a new generic NAS (NFS) mount point and adds it to an existing generic NAS protectioon job. If the mount point is already registered or already protected by the specified job, the script will skip the unneeded operations. 

## Components

* addNFSMountToProtectionJob.sh: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:
```bash
./addNFSMountToProtectionJob.sh -v mycluster -u myusername -j 'NAS Job Name' -m 192.168.1.4:/var/nfs2
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
