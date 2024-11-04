# Register an Isilon Protection Source using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script registers an Isilon as a protection source.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerIsilon/registerIsilon.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x registerIsilon.py
# end download commands
```

## Components

* [registerIsilon.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/registerIsilon/registerIsilon.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./registerIsilon.ps1 -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -n isilon1.mydomain.net \
                     -au myadmin \
                     -su 'mydomain.net\myuser' \
                     -b 10.1.1.1 \
                     -b 10.2.1.1
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -n, --name: name or IP of isilon to register
* -au, --apiuser: API username to connect to Isilon
* -ap, --apipassword: (optional) API password to connect to Isilon (will be prompted if omitted)
* -su, --smbuser: (optional) SMB domain\username to protect SMB volumes
* -sp, --smbpassword: (optional) SMB password to protect SMB volumes (will be prompted if required)
* -b, --blacklistip: (optional) IP address to blacklist (repeat for multiple)
* -l, --blacklist: (optional) text file of IPs to blacklist (one per line)
