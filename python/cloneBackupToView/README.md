# Clone Backup Data to a View Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script clones backup files to an NFS view.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/cloneBackupToView/cloneBackupToView.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x cloneBackupToView.py
# end download commands
```

## Components

* [cloneBackupToView.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/cloneBackupToView/cloneBackupToView.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./cloneBackupToView.py -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -j 'My Backup Job' \
                       -n myviewname \
                       -w 192.168.1.0,255.255.255.0 \
                       -w 192.168.2.23
```

To delete the view after you're done with it:

```bash
./cloneBackupToView.py -v mycluster \
                       -u myuser \
                       -d mydomain.net \
                       -n myviewname \
                       -x
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: (optional) name of the job to clone
* -o, --objectname: (optional) name of object from job to clone
* -a, --allruns: (optional) clone all available runs (default is latest run only)
* -n, --viewname: name of view to use or create
* -q, --qospolicy: (optional) 'Backup Target Low', 'Backup Target High', 'TestAndDev High' or 'TestAndDev Low' (default is 'TestAndDev High')
* -w, --whitelist: (optional) e.g. '192.168.1.0,255.255.255.0' or '192.168.2.23' (repeat for multiple entries)
* -x, --deleteview: (optional) delete existing view and exit
* -y, --daysback: (optional) clone runs that occured in the past X days (default is all runs in retention)

## Note

The Protection Job and the View must be in the same Storage Domain.
