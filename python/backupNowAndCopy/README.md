# Backup Now and Copy using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script performs a run of a protection job including replication and archival tasks. This script is somewhat 'hard-coded' in the sense that it expects to find at least one replication task and at least one archival task in the policy that is applied to the protection job being run.

I could change the script if we want to specify the replica and archive targets and retentions rather than retrieving them from the policy.

## Components

* backupNowAndCopy.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:
```bash
bash:~/scripts/python$ ./backupNowAndCopy.py -v mycluster -u myuser -d mydomain.net -j 'My Job'
Connected!
Running My Job...
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
