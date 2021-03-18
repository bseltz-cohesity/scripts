# Run a Series of Disabled Jobs Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These python script runs a series of disabled jobs, one at a time, leaving them disabled when fihished.

## Components

* jobScheduler.py: schedules a group of jobs to run
* jobRunner.py: runs the jobs one at a time
* pyhesity.py: the Cohesity REST API helper module

## Download The Scripts

The script is designed to run from the Cohesity cluster. To download and install the script, SSH into the cohesity cluster and run the following commands to download the scripts:

```bash
mkdir /home/cohesity/data/scripts
cd /home/cohesity/data/scripts
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/jobRunner/jobRunner.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/jobRunner/jobScheduler.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x jobRunner.py
chmod +x jobScheduler.py
```

The scripts are meant to be scheduled (using cron for example) but we can run the scripts interactively for testing. First we run the jobScheduler. This creates a group folder with a trigger file per job, marking each job as 'not started'.

```python
./jobScheduler.py -g 'myjobgroup' -j 'Job1' -j 'Job2' -j 'Job3'
```

## Parameters for jobScheduler

* -g, --groupname: name of job group to create
* -j, --jobname: name of protection jobs to add to the group. Add one for each job like -j Job1 -j Job2 -j job3

Later, the jobRunner script is run. It will find the least recently run job of the group and enable, run and disable the job, marking its trigger file 'started'.

```python
./jobRunner.py -v mycluster -u myuser -d mydomain.net -g 'myjobgroup' -k 30 -a s3target -ka 90 -r drcluster -kr 14
```

## Parameters for jobRunner

* -v, --vip: name of Cohesity cluster to connect to
* -u, --username: short username to authenticate to the cluster
* -d, --domain: active directory domain of user (default is local)
* -g, --groupname: name of the job group to process
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

Let's say that you want the jobs to start at 9PM eastern. Remember to adjust to pacific time, which would be 6PM (18:00). Enter the following line in crontab:

```text
0 18 * * * /home/cohesity/data/scripts/jobScheduler.py -g 'MyJobGroup' -j 'Job1' -j 'Job2' -j 'Job3'
```

Next, we add the jobRunner to run periodically (say every ten minutes)

```text
*/10 * * * * /home/cohesity/data/scripts/jobRunner.py -v mycluster -u myuser -d mydomain.net -g 'MyJobGroup' -k 30 -a s3target -ka 90 -r drcluster -kr 14
```
