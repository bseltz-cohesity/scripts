# Recover a NAS Volume as a Cohesity View Using python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script clones a NAS volume as a Cohesity view. IF the view already exists, it will delete it and recreate it from the newer version of the NAS volume backup.

## Components

* refreshNASclone.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./refreshNASclone.py -s mycluster -u myuser -v '\\mynas.mydomain.net\myshare' -n test
```

The script writes no output to the screen (it is designed to run from a scheduler), but will log to a file log-refreshNASclone.txt. The log will show something like this:

```text
started at 2019-03-17 18:25:10
deleting view test
recovering \\mynas.mydomain.net\myshare from 2019-03-17 18:24:52 to test
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
