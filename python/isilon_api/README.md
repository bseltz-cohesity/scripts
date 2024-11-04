# Isilon API Function Library for Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a function library for Isilon API that uses session cookie authentication with CSRF protection. This is not for the Cohesity API but is useful when connecting to Isilon API.

## Download the Module

Use the following command to download the module:

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/isilon_api/isilon_api.py
```

## Installing the Prerequisites

isilon_api.py requires the `requests` python module. To install it, do one of the following:

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```

## Basic Usage

```python
from isilon_api import *
isilonauth(endpoint=myendpoint, username=username, password=password)
```

### Stored Passwords

Although there is a password parameter, it is not recommended to use it. Instead, the fist time you attempt to authenticate to an API, you will be prompted for your password. The password will be stored in <user's home folder>/.basic-api. The stored password will then be used automatically so that scripts can run unattended.

### API Calls

Once authenticated, you can make API calls. For example:

```python
nodes = isilonapi('get', '/platform/1/license/licenses')
```

### Date Conversions

Some APIs store dates in Unix Epoch Microseconds. That's the number of microseconds since midnight on Jan 1, 1970. Several conversion functions have been included to handle these dates.

```python
api('get','protectionJobs')[0]['creationTimeUsecs']
1533978038503713
  
usecsToDate(1533978038503713)
'2018-08-11 05:00:38'
  
dateToUsecs('2018-08-11 05:00:38')
1533978038000000
  
timeAgo('24','hours')
1534410755000000
```
