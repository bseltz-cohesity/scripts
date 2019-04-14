# Extend Monthly Retention using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script extends the retention of a specified snapshot (e.g. 1st of the month) and extends its retention to the specified number of days.

## Components

* extendMontlyRetention.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# begin download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/extendMonthlyRetention/extendMonthlyRetention.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/extendMonthlyRetention/pyhesity.py
chmod +x extendMonthlyRetention.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./extendMonthlyRetention.py -v mycluster -u myusername -d mydomain.net -j 'My Job' -k 365 -m 1
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
* -m, --dayOfMonth: Day of the month to extend (defaults to 1)
* -k, --daysToKeep: The number of days (from the date of the run) to retain the snapshot

## Notes

If no snapshot exists from day m (because it was not completed), the next successful snapshot will be retained instead.

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
