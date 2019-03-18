# Backup Now and Copy using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script performs a runNow on a protection job and optionally replicates and/or archives the backup to the specified targets. Also, the script will enable a disabled job to run it, and disable it when done.

## Components

* backupNowAndCopy.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:
```bash
bash:~/scripts/python$ ./backupNowAndCopy.py -v mycluster -u myuser -d mydomain.net -j 'My Job'
Connected!
Running My Job...
```

## Optional Parameters

*  -a,  --archiveTo: (optional) name of archival target to archive to
*  -ka, --keepArchiveFor: days to keep in archive (default is 5 days)
*  -r,  --replicateTo: (optional) name of remote cluster to replicate to
*  -kr, --keepReplicaFor: days to keep replica for (default is 5 days)
*  -e,  --enable: (optional) enable a paused job before running, then disable when done


## Download Instructions
Run the following commands to download the script(s):
```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/backupNowAndCopyV2/backupNowAndCopy.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/backupNowAndCopyV2/pyhesity.py
chmod +x backupNowAndCopy.py
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
