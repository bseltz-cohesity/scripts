# Scheduled Enablement of Support Channel using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script schedules the opening of Cohesity support channel for some time in the future, and sets how long support channel will remain open. This allows the customer to, for example, schedule secure channel now, to open after hours for a few hours, such that Cohesity support can access the customer's Cohesity cluster in the evening.

## Components

* [scheduleRT.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/scheduleRT/scheduleRT.py): the main python script to set the schedule
* [enableRT.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/scheduleRT/enableRT.py): the script that runs as scheduled
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

## Deployment

* ssh into a node of the Cohesity cluster
* Create a folder such as /home/cohesity/scripts and place all files in the folder together.
* make scheduleRT.py executable (chmod +x scheduleRT.py)
* make enableRT.py executable (chmod +x enableRT.py)

You can then run the script like so:

```bash
[cohesity@mycluster-node-1]$ cd scripts
[cohesity@mycluster-node-1 scripts]$
./scheduleRT.py -v 'mycluster' -u 'admin' -d 'local' -hr '2' -s '2019-02-28 11:07:00'
Connected!
Scheduled RT to open at 2019-02-28 11:07:00
```

You can confirm that the script has been scheduled by running the command:

```bash
[cohesity@bseltzve01-00505689c530-node-1 scripts]$ crontab -l
*/10 * * * * /home/cohesity/scripts/enableRT.py -v 'mycluster' -u 'admin' -d 'local' -hr '2' -s '2019-02-28 11:07:00'
```

You can also tell the script to repeat for x number of days (support channel will open at the same time each day for the specified number of days) using the -r parameter:

```bash
./scheduleRT.py -v 'mycluster' -u 'admin' -d 'local' -hr '2' -s '2019-02-28 11:07:00' -r 3
```

## Note about Timezones

Before selecting a date and time to open support channel, please note that the Cohesity cluster is likely set to US/Pacific time. Please adjust your times to that timezone. For example, if I am in the US/Eastern timezone, and I want support channel to open at 10PM eastern on Feb 28 2019, then I will use the date time '2019-02-28 19:00:00' (7PM pacific).

## Download the Scripts

Use the following commands to download the script:

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/scheduleRT/enableRT.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/scheduleRT/scheduleRT.py
chmod +x scheduleRT.py
chmod +x enableRT.py
```

## Stored Password

The pyhesity.py module (see below) stores your Cohesity password in encrypted format, so that the script can run unattended. If your password changes, you can update your stored password by performing the following in an interactive python session:

```bash
$ python
Python 2.7.10 (default, Oct  6 2017, 22:29:07)
[GCC 4.2.1 Compatible Apple LLVM 9.0.0 (clang-900.0.31)] on darwin
Type "help", "copyright", "credits" or "license" for more information.
>>>
>>>
>>> from pyhesity import *
>>> apiauth('mycluster','admin','local','updatepw')
Enter your password: *****
Confirm your password: *****
Connected!
>>>
>>>
>>> exit()
```

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
