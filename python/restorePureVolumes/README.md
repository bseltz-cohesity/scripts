# Restore Pure Volumes from Cohesity using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script restores Pure Storage volumes from a Cohesity backup.

## Components

* [restorePureVolumes.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restorePureVolumes/restorePureVolumes.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restorePureVolumes/restorePureVolumes.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restorePureVolumes.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./restorePureVolumes.py -v mycluster \
                        -u myusername \  
                        -a mypure \
                        -j 'my pure backup' \
                        -n myserver_lun1 \
                        -n myserver_lun2 \
                        -p restore- \
                        -s 0410
# end example
```

By default, the latest backup will be restored, but if you want to use a previous backup, you can list the avaiable versions using -x, --showversions:

```bash
# example
./restorePureVolumes.py -v mycluster \
                        -u myusername \  
                        -a mypure \
                        -j 'my pure backup' \
                        -n myserver_lun1 \
                        -n myserver_lun2 \
                        -p restore- \
                        -s 0410 \
                        -x
# end example
```

From the ouput, find the runid you want and use -r, --runid to specify that backup:

```bash
# example
./restorePureVolumes.py -v mycluster \
                        -u myusername \  
                        -a mypure \
                        -j 'my pure backup' \
                        -n myserver_lun1 \
                        -n myserver_lun2 \
                        -p restore- \
                        -s 0410 \
                        -r 1477739
# end example
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: name of Cohesity protection group to restore from
* -a, --purename: name of registered pure array
* -v, --volumename: (optional) volume name to recover (repeat for multiple)
* -l, --volumelist: (optional) text file of volumes names to recover (one per line)
* -p, --prefix: (optional) prefix to apply to recovered volumes
* -s, --suffix: (optional) suffix to apply to recovered volumes (dash will be added automatically)
* -x, --showversions: (optional) show available versions
* -r, --runid: (optional) specifiy runid (from showversions) to use for restore

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module. You can get a copy and read about it here:

<https://github.com/cohesity/community-automation-samples/tree/main/python>

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```
