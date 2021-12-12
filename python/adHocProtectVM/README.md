# Backup New VM Once using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script performs an ad hoc backup of a new VM. It refreshes a vCenter source, adds a new VM to a protection job, backs up the VM, waits for the backup to finish, then removes the VM from the job.

## Components

* adHocProtectVM.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
bash:~/scripts/python$./adHocProtectVM.py -v mycluster -u myuser -vc vCenter6.mydomain.net -vm wiki -job "vm backup" -k 30
Connected!
refreshing vCenter6.mydomain.net...
adding Wiki to VM Backup job...
Running vm backup...
RunID: 7474 Status: kSuccess
Run URL: https://mycluster/protection/job/7/run/8365/1547289225383428/protection
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
