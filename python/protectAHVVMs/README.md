# Protect AHV VMs Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script protects Nutanix Acropolis VMs.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/protectAHVVMs/protectAHVVMs.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x protectAHVVMs.py
# end download commands
```

## Components

* [protectAHVVMs.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/protectAHVVMs/protectAHVVMs.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectAHVVMs.py -v mycluster \
                   -u myuser \
                   -d mydomain.net \
                   -j 'My Backup Job' \
                   -s myahvcluster.mydomain.net \
                   -l vmlist.txt
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -j, --jobname: name of the job to add the vms to
* -s, --sourcename: name of registered AHV source
* -n, --vmname: (optional) name of VM to protect (repeat for multiple)
* -l, --vmlist: (optional) text file containing VMs to protect (one per line)
* -sd, --storagedomain: (optional) name of storage domain to create job in (default is DefaultStorageDomain)
* -p, --policyname: (optional) name of protection policy to use for new job (only required for new job)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)
