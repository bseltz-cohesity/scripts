# Restore Pure Volumes from Cohesity using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script restores Pure Storage volumes from a Cohesity backup.

## Components

* restorePureVolumes.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/restorePureVolumes/restorePureVolumes.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x restorePureVolumes.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./restorePureVolumes.py -c mycluster \
                        -u myusername \  
                        -a mypure \
                        -v myserver_lun1 \
                        -v myserver_lun2 \
                        -p restore- \
                        -s -0410
# end example
```

```text
Connected!
Restoring mypure/myserver_lun1 as mypure/restore-myserver_lun1-0410
Restoring mypure/myserver_lun2 as mypure/restore-myserver_lun2-0410
```

## Parameters

* -c', '--cluster': Cohesity cluster name or IP
* -u', '--username': Cohesity Username
* -d', '--domain': Cohesity User Domain
* -a', '--purename': name of registered pure array
* -v', '--volumename': volume name(s) to recover
* -l', '--volumelist': file of volumes names to recover
* -p', '--prefix': prefix to apply to recovered volumes
* -s', '--suffix': suffix to apply to recovered volumes

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module. You can get a copy and read about it here:

<https://github.com/bseltz-cohesity/scripts/tree/master/python>

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```
