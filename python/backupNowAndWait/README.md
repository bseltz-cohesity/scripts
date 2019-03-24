# Backup Now and Wait using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script performs a run of a protection job and waits for it to finish. 

## Components

* backupNowAndWait.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
bash:~/scripts/python$ ./backupNowAndWait.py -v mycluster -u myuser -j "VM Backup" -k 30
Connected!
Running VM Backup...
New Job Run ID: 6811
Job finished with status: kSuccess
Run URL: https://bseltzve01/protection/job/7/run/8365/1547289225383428/protection
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
