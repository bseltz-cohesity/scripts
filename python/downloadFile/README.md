# Download files from Cohesity backups using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script downloads a file from a Cohesity backup.

## Components

* [downloadFile.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/downloadFile/downloadFile.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/downloadFile/downloadFile.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x downloadFile.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./downloadFile.py -v mycluster -u myusername -d mydomain.net -o myserver -f 'scripts/v' -p /Users/myusername/Downloads
```

```text
Connected!

Please select which file to recover or press CTRL-C to exit

0  /C/scripts/vcenter.cmd
1  /C/scripts/vcenterDR.cmd

Selection: 1

Please select a version of the file to recover

0  2019-06-10 23:40:00
1  2019-06-09 23:40:00
2  2019-06-08 23:40:01
3  2019-06-07 23:40:00
4  2019-06-06 23:40:01
5  2019-06-05 23:40:01
6  2019-06-04 23:40:00
7  2019-06-03 23:40:00
8  2019-06-02 23:40:01
9  2019-06-01 23:40:01

Selection: 0
Downloading vcenterDR.cmd to /Users/myusername/Downloads
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -o, --objectname: Name of protected object
* -f, --filesearch: partial file path/name
* -p, --destinationpath: local path to download to

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
