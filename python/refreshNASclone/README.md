# Recover a NAS Volume as a Cohesity View Using python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script clones a NAS volume as a Cohesity view. If the view already exists, it will delete it and recreate it from the newer version of the NAS volume backup.

## Components

* [refreshNASclone.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/refreshNASclone/refreshNASclone.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

## Download The Scripts

Run the following commands to download the scripts:

```bash
mkdir /home/cohesity/scripts
cd /home/cohesity/scripts
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/refreshNASclone/refreshNASclone.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x refreshNASclone.py
```

Place both files in a folder together and run the main script like so:

```bash
./refreshNASclone.py -s mycluster -u myuser -v '\\mynas.mydomain.net\myshare' -n test [ - smb ]
```

Note: the -smb parameter is optional. When set, it will make the view protocol accessSMB only, will make she shares browsable and will enable access based enumeration.

If this is the first time connecting with this user, you will be prompted for your password, which will be stored encrypted for later use by the script. See below for instructions on updating this stored password.

The script writes no output to the screen (it is designed to run from a scheduler), but will log to a file log-refreshNASclone.txt. The log will show something like this:

```text
started at 2019-03-17 18:25:10
deleting view test
recovering \\mynas.mydomain.net\myshare from 2019-03-17 18:24:52 to test
```

## A Note about Timezones

Cohesity clusters are typically set to US/Pacific time, rgardless of their physical location. If you schedule this script to run on a Cohesity cluster, make sure to account for the difference between your time zone and the cluster's timezone. For example, if you want to run the script at 5am eastern time, then schedule it to run at 2am on the cluster.

## Schedule the Script to Run Daily

Assuming that you want the view refreshed daily, you can use cron to schedule the script to run. Simply type the command:

```bash
crontab -e
```

Let's say that you downloaded the scripts into /home/cohesity/scripts and you want it to run at 5am eastern time daily. Remember to adjust to pacific time. Enter the following line in crontab:

```text
0 2 * * * /home/cohesity/scripts/refreshNASclone.py -s mycluster -u myuser -v '\\mynas.mydomain.net\myshare' -n test -smb
```

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

Note: a Cohesity cluster already has these prerequisites. If you're running the script on a Cohesity cluster, you can skip this step.

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```

## Stored Passwords

The pyhesity.py module stores your Cohesity password in encrypted format, so that the script can run unattended. If your password changes, you can update your stored password by performing the following in an interactive python session:

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
