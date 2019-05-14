# Run a Series of Disabled Jobs Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script runs a series of disabled jobs, one at a time, leaving them disabled when fihished.

## Components

* jobSeries.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

## Download The Scripts

The script is designed to run from the Cohesity cluster. To download and install the script, SSH into the cohesity cluster and run the following commands to download the scripts:

```bash
mkdir /home/cohesity/data/scripts
cd /home/cohesity/data/scripts
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/jobSeries/jobSeries.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/jobSeries/pyhesity.py
chmod +x jobSeries.py
```

The script can be run as a scheduled cron task (see below) or run interactively like so:

```python
./jobSeries.py -v mycluster -u myuser -d mydomain.net -k 5 -j 'Job1' -j 'Job2' -j 'Job3'
Connected!
checking if Job1 is already running...
checking if Job2 is already running...
checking if Job3 is already running...
Running Job1...
New Job Run ID: 111530
Running Job2...
New Job Run ID: 111534
Running Job3...
New Job Run ID: 111541
```

## Parameters

* -v, --vip: name of Cohesity cluster to connect to
* -u, --username: short username to authenticate to the cluster
* -d, --domain: active directory domain of user (default is local)
* -j, --jobname: name of protection job to run. Add one for each job like -j Job1 -j Job2
* -k, --keepLocalFor: days to keep local snapshot (default is 5 days)
* -a, --archiveTo: name of archival target to archive to (default is None)
* -ka, --keepArchiveFor: days to keep in archive (default is 5 days)
* -r, --replicateTo: name of remote cluster to replicate to (default is None)
* -kr, --keepReplicaFor: days to keep replica for (default is 5 days)
* -t, --backupType: choose one of kRegular, kFull or kLog backup types. Default is kRegular (incremental)

## Stored Passwords

The script will need to use a stored, encrypted password file to authenticate at runtime. To setup this password file, start an interactive python session and run the following commands:

```bash
$ python
Python 2.7.10 (default, Oct  6 2017, 22:29:07)
[GCC 4.2.1 Compatible Apple LLVM 9.0.0 (clang-900.0.31)] on darwin
Type "help", "copyright", "credits" or "license" for more information.
>>>
>>>
>>> from pyhesity import *
>>> apiauth('mycluster','myusername','mydomain.net',updatepw=True)
Enter your password: *****
Confirm your password: *****
Connected!
>>>
>>>
>>> exit()
```

Note: you can use the same process to update the stored password if it ever needs to be changed.

## A Note about Timezones

Cohesity clusters are typically set to US/Pacific time regardless of their physical location. If you schedule this script to run on a Cohesity cluster, make sure to account for the difference between your time zone and the cluster's timezone. For example, if you want to run the script at 5am eastern time, then schedule it to run at 2am on the cluster.

## Schedule the Script to Run using Cron

We can schedule the script to run using cron.

```bash
crontab -e
```

Let's say that you want the script to run at 9PM eastern. Remember to adjust to pacific time, which would be 6PM (18:00). Enter the following line in crontab:

```text
0 18 * * * /home/cohesity/data/scripts/jobSeries.py -v mycluster -u myuser -d mydomain.net -k 5 -j 'Job1' -j 'Job2' -j 'Job3'
```

If you want to keep daily weekly and monthly backups, you can do something like this:

```bash
# Run daily at 6pm except for Sunday or the 1st of the month, and keep for 7 days
0 18 2-31 * 1-6 /home/cohesity/data/scripts/jobSeries.py -v mycluster -u myuser -d mydomain.net -k 7 -j 'Job1' -j 'Job2' -j 'Job3'
# Run weekly on Sunday, except for the 1st of the month, and keep for 31 days
0 18 2-31 * 0 /home/cohesity/data/scripts/jobSeries.py -v mycluster -u myuser -d mydomain.net -k 31 -j 'Job1' -j 'Job2' -j 'Job3'
# Run on the 1st of the month and keep for 365 days
0 18 1 * * /home/cohesity/data/scripts/jobSeries.py -v mycluster -u myuser -d mydomain.net -k 365 -j 'Job1' -j 'Job2' -j 'Job3'
```
