# Unprotect VMs Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script removes VMs from protection groups. Note that this will not work with autoprotected VMs, only VMs that are explicitely added to protection gorups.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/unprotectVM/unprotectVM.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x unprotectVM.py
# end download commands
```

## Components

* [unprotectVM.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/unprotectVM/unprotectVM.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./unprotectVM.py -v mycluster \
                 -u myuser \
                 -d mydomain.net \
                 -n vm1 \
                 -n vm2 \
                 -l vmlist.txt
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -n, --vmname: (optional) name of server to add to the job (use multiple times for multiple)
* -l, --vmlist: (optional) list of server names in a text file (one per line)
* -j, --jobname: (optional) only remove VM from this job (default is all jobs)
* -s, --joblist: (optional) text file of job names to remove VMs from (one per line)
