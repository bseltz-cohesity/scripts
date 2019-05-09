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

Edit the script and configure the settings section:

```python
### settings
vip = 'mycluster'
username = 'myusername'
domain = 'mydomain.net'
replicateTo = 'anothercluster'
keepReplicaFor = 5
archiveTo = 'archivetarget'
keepArchiveFor = 5
jobs = ['Job1', 'Job2', 'Job3']
```

Note: If you don't want to replicate, set replicateTo = None and the same can be done for archiveTo.

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

Cohesity clusters are typically set to US/Pacific time, rgardless of their physical location. If you schedule this script to run on a Cohesity cluster, make sure to account for the difference between your time zone and the cluster's timezone. For example, if you want to run the script at 5am eastern time, then schedule it to run at 2am on the cluster.

## Schedule the Script to Run Daily

We can schedule the script to run using cron.

```bash
crontab -e
```

Let's say that you want the script to run at 9PM eastern. Remember to adjust to pacific time, which would be 6PM (18:00). Enter the following line in crontab:

```text
0 18 * * * /home/cohesity/data/scripts/jobSeries.py
```
