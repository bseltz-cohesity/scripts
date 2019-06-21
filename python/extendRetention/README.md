# Extend Retention using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script extends the retention of exiting snapshots. It can set new expiration dates for weekly, monthly and yearly snapshots.

## Components

* extendRetention.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

## Download The Scripts

The script is designed to run from the Cohesity cluster. To download and install the script, SSH into the cohesity cluster and run the following commands to download the scripts:

```bash
# begin download commands
mkdir /home/cohesity/data/scripts
cd /home/cohesity/data/scripts
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/extendRetention/extendRetention.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/extendRetention/pyhesity.py
chmod +x extendRetention.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./extendRetention.py -v mycluster -u myusername -d mydomain.net -j 'My Job' \
                     -wr 35 -w 6 -mr 365 -m 1 -ms mail.mydomain.net -mp 25 \
                     -to myuser@mydomain.com -fr someuser@mydomain.com
```

The script output should be similar to the following:

```text
Connected!
2019-04-01 01:40:00 extending retention to 2020-04-01 01:40:00
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: Name of protection job
* -y, --dayofyear: (optional) day of year to extend yearly snapshot (default is 1)
* -m, --dayofmonth: (optional) day of month to extend monthly snapshot (default is 1)
* -w, --dayofweek: (optional) day of week to extend weekly snapshot, Monday=0, Sunday=6 (default is 6)
* -yr, --yearlyretention: (optional)
* -mr, --monthlyretention: (optional)
* -wr, --weeklyretention: (optional)
* -ms, --mailserver: (optional) SMTP server address to send reports to
* -mp, --mailport: (optional) SMTP port to send reports to (default is 25)
* -to, --sendto: (optional) email address to send reports to
* -fr, --sendfrom: (optional) email address to send reports from

## The Python Helper Module

The helper module, pyhesity.py, provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

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

Let's say that you want the script to run every Monday at 7am eastern. Remember to adjust to pacific time, which would be 4am. Enter the following line in crontab:

```text
0 4 * * 1 /home/cohesity/data/scripts/extendRetention.py -v mycluster -u myusername -d mydomain.net -j 'My Job' -wr 35 -w 6 -mr 365 -m 1 -ms mail.mydomain.net -mp 25 -to myuser@mydomain.com -fr someuser@mydomain.com
```
