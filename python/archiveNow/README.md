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
