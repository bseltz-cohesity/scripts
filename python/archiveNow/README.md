# Archive a Snapshot Now using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script archives an existing local snapshot.

## Components

* archiveNow.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/archiveNow/archiveNow.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/archiveNow/pyhesity.py
chmod +x archiveNow.py

```

Place both files in a folder together and run the main script like so:

```bash
./archiveNow.py -v mycluster -u myuser -d mydomain.net -j myjob -r '2019-03-26 14:55:00'
```

The date entered is the date of the protection run that you want to archive. The script output should be similar to the following:

```text
Connected!
archiving snapshot from 2019-03-26 14:55:18...
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: Name of protection job
* -r, --rundate: Date and time of protection run to archive, e.g. '2019-03-26 14:37:00'
* -k, --keepfor: (optional) keepfor X days. Required if there is no archive policy for the job
* -t, --newtarget: (optional) name of the external target. Required if there is no archive policy for the job
* -f, --fromtoday: (optional) calculate -k from today instead of from snapshot date

## Notes

If the job has a policy applied with an archival policy element, by default the script will use the target and retention specified in the policy. The retention to be set will be calculated from the snapshot date by default, so if the retention is 10 days, but the snapshot occured 2 days ago, then the retention will be set to 8 days.

Using the -k parameter overrides the retention specified in the policy, or specifies a retention when the job has no archival policy. Again, retention is adjusted based on the age of the snapshot.

Using the -t parameter overrides the archival target specified in the policy, or specifies a target when the job has no archival policy.

Using the -f parameter ignores the snapshot age and sets the retention to k days from today.

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
