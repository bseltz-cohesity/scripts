# Recover a VM using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script recovers a VM.

## Components

* recoverVM.sh: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./recoverVM.sh -v mycluster -u admin -vm centos1 -s test
Connected!
recovering centos1 as centos1-test...
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
