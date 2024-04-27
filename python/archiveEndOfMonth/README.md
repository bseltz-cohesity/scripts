# Archive an End Of Month Snapshot using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script archives an existing local snapshot taken on the last day of the month.

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/archiveEndOfMonth/archiveEndOfMonth.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x archiveEndOfMonth.py
# end download commands
```

## Components

* [archiveEndOfMonth.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/archiveEndOfMonth/archiveEndOfMonth.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./archiveEndOfMonth.py -v mycluster -u myuser -d mydomain.net -j myjob1 -j myjob2 -k 365 -t S3
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: Name of protection job (repeat the -j parameter for multiple jobs)
* -k, --keepfor: keepfor X days
* -t, --targetname: name of the external target to archive to

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

### Stored Passwords

There is no parameter to provide your password. The fist time you authenticate to a cluster, you will be prompted for your password. The password will be encrypted and stored in the user's home folder. The stored password will then be used automatically so that scripts can run unattended.

If your password changes, use apiauth with updatepw to prompt for the new password. Run python interactively and enter the following commands:

```python
from pyhesity import *
apiauth('mycluster', 'myuser', 'mydomain', updatepw=True)
```

If you don't want to store a password and want to be prompted to enter your password when you run your script, use prompt=True

## A Note about Timezones

Cohesity clusters are typically set to US/Pacific time regardless of their physical location. If you schedule this script to run on a Cohesity cluster, make sure to account for the difference between your time zone and the cluster's timezone. For example, if you want to run the script at 5am eastern time, then schedule it to run at 2am on the cluster.

## Schedule the Script to Run Weekly

We can schedule the script to run using cron.

```bash
crontab -e
```

Let's say that you want the script to run every Saturday at 7am eastern. Remember to adjust to pacific time, which would be 4am. Enter the following line in crontab:

```bash
# crontab example
0 4 * * 6 /home/cohesity/data/scripts/archiveEndOfMonth.py -v mycluster -u myusername -d mydomain.net -j myjob1 -j myjob2 -k 365 -t S3
# end crontab example
```
