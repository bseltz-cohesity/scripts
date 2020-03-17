# Cohesity REST API Python Examples

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Cohesity REST API Helper Module: pyhesity.py

pyhesity.py contains a set of functions that make it easy to use the Cohesity REST API, including functions for authentication, making REST calls, and managing date formats.

### Download the Module

Use the following command to download the module:

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
```

### Installing the Prerequisites

pyhesity.py requires the requests python module. To install it, do one of the following:

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```

### Basic Usage

```python
from pyhesity import *
apiauth('mycluster', 'admin') # domain defaults to local
# or
apiauth('mycluster', 'myuser', 'mydomain') # specify an Active Directory domain
```

### Stored Passwords

There is no parameter to provide your password. The fist time you authenticate to a cluster, you will be prompted for your password. The password will be encrypted and stored in the user's home folder. The stored password will then be used automatically so that scripts can run unattended.

If your password changes, use apiauth with updatepw to prompt for the new password.

```python
from pyhesity import *
apiauth('mycluster', 'myuser', 'mydomain', updatepw=True)
```

If you don't want to store a password and want to be prompted to enter your password when you run your script, use prompt=True

```python
from pyhesity import *
apiauth('mycluster', 'myuser', 'mydomain', prompt=True)
```

### API Calls

Once authenticated, you can make API calls. For example:

```python
print(api('get', 'protectionJobs')[0]['name'])
VM Backup
```

### Date Conversions

Cohesity stores dates in Unix Epoch Microseconds. That's the number of microseconds since midnight on Jan 1, 1970. Several conversion functions have been included to handle these dates.

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

### Helios Access

You can connect to Helios. When prompted for a password, enter the apiKey (create one in Helios under access management).

```python
apiauth()
```

and list helios connected clusters:

```text
heliosClusters()

ClusterID           SoftwareVersion                     ClusterName
---------           ---------------                     -----------
3245772218955543    6.4.1_release-20191219_aafe3274     BKDataRep01
5860211595354073    6.4.1_release-20191219_aafe3274     BKDRRep02
8535175768906402    6.4.1a_release-20200127_bd2f17b1    Cluster-01
```

then choose a cluster to operate on:

```text
heliosCluster('Cluster-01')

Using Cluster-01
```
