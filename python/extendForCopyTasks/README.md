# Extend Retention for Local Snapshots with Unfinished Copy Tasks using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script extends the retention of local snapshots that have unfinished copy tasks (replication or archival)

## Download the script

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/extendForCopyTasks/extendForCopyTasks.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x extendForCopyTasks.py
# End download commands
```

## Components

* [extendForCopyTasks.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/extendForCopyTasks/extendForCopyTasks.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place the files in a folder together, then we can run the script. If you omit the -commit switch, it will run in test mode:

```bash
# if snapshot is expiring in less than 3 days, extend it to 7 days from today (test mode)
./extendForCopyTasks.py -v mycluster \
                        -u myusername \
                        -d mydomain.net \
                        -a 3 \
                        -x 7
```

To commit the changes, include the -commit switch:

```bash
# if snapshot is expiring in less than 3 days, extend it to 7 days from today (commit)
./extendForCopyTasks.py -v mycluster \
                        -u myusername \
                        -d mydomain.net \
                        -a 3 \
                        -x 7 \
                        -commit
```

To send an email report of snapshots that were extended:

```bash
# if snapshot is expiring in less than 3 days, extend it to 7 days from today (commit)
./extendForCopyTasks.py -v mycluster \
                        -u myusername \
                        -d mydomain.net \
                        -a 3 \
                        -x 7 \
                        -commit \
                        -ms smtp.mydomain.net \
                        -fr mycluster@mydomain.net \
                        -to me@mydomain.net \
                        -to them@mydomain.net
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) name of tenant to impersonate
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to (repeat for multiple)
* -mfa, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -a, --alertdays: (optional) extend snapshot if expiring in less than X days (default is 2)
* -x, --extenddays: (optional) extend snapshot to X days from today (default is 7)
* -n, --numruns: (optional) number of runs to retrieve per API call (default is 1000)
* -commit, --commit: (optional) perform extensions (if omitted, only show what would be done)
* -o, --outputpath: (optional) path for output files (default is '.')

## Optional Email Parameters

* -ms, --mailserver: (optional) SMTP gateway to send mail through
* -mp, --mailport: (optional) SMTP gateway port (default is 25)
* -to, --sendto: (optional) email address to send report (repeat for multiple)
* -fr, --sendfrom: (optional) email address to send from

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
