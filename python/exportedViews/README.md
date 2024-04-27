# List Exported Views using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script list views and to what IP addresses they are exported.

## Downloading the Files

Go to the folder where you want to download the files, then run the following commands:

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/exportedViews/exportedViews.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x exportedViews.py
```

## Components

* [exportedViews.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/exportedViews/exportedViews.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./exportedViews.py -s mycluster -u admin [ -d domain ]

Connected!

Listing Exported Views...

    View Name: clone-test
  Description:
Logical Bytes: 17180921695
      Created: 2019-08-22 04:20:33
    Whitelist:
               192.168.1.205
-------

    View Name: cohesity_int_143614
  Description: Magneto clone view
Logical Bytes: 0
      Created: 2019-07-09 20:54:26
    Whitelist:
               0.0.0.0
-------

    View Name: cohesity_int_143541
  Description:
Logical Bytes: 1148552
      Created: 2019-07-09 17:35:51
    Whitelist:
               0.0.0.0
               192.168.1.205
-------

    View Name: Stuff
  Description:
Logical Bytes: 85974
      Created: 2019-05-30 04:12:09
    Whitelist:
               0.0.0.0
-------

    View Name: oracle
  Description:
Logical Bytes: 14164519424
      Created: 2019-03-03 16:38:11
    Whitelist:
               0.0.0.0
-------

    View Name: S3Bucket
  Description:
Logical Bytes: 419432001
      Created: 2019-02-13 17:47:23
    Whitelist:
               0.0.0.0
-------

    View Name: Utils
  Description:
Logical Bytes: 267966121
      Created: 2019-01-24 10:39:07
    Whitelist:
               0.0.0.0
-------

    View Name: Scripts
  Description:
Logical Bytes: 400475
      Created: 2019-01-21 06:01:28
    Whitelist:
               0.0.0.0
-------
```

## Parameters

* -v, --server: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local

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
