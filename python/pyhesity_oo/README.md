# Python Class Library and Helper Functions (Beta)

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## The API Helper Module: pyhesity_oo.py

pyhesity_oo.py is a new variant of the existing pyhesity.py, which offers a more object oriented experience for connecting to the Cohesity REST API. The goal of this module is to provide multiple concurrent connections to Cohesity clusters, vs a single connection provided by pyhesity.py.

### Installing the Prerequisites

pyhesity_oo.py requires the requests python module. To install it, do one of the following:

```bash
sudo yum install python-requests
```
or

```bash
sudo easy_install requests
```

### Basic Usage
```python
from pyhesity_oo import *
myCluster = CohesityCluster('bseltzve01', 'admin') # domain defaults to local
# or
myCluster = CohesityCluster('bseltzve01', 'admin', 'mydomain.com') # Active Directory domain
```

### Stored Passwords
There is no parameter to provide your password! The fist time you authenticate to a cluster, you will be prompted for your password. The password will be encrypted and stored in the user's home folder. The stored password will then be used automatically so that scripts can run unattended. 

If your password changes, use apiauth with updatepw to prompt for the new password.
```python
from pyhesity_oo import *
myCluster = CohesityCluster('bseltzve01', 'admin', 'local', updatepw=True)
```

### API Calls
Once authenticated, you can make API calls. For example:
```python
from pyhesity_oo import *
myCluster = CohesityCluster('bseltzve01','admin')
print "cluster name is: " + myCluster.get('cluster')['name']
```
```text
cluster name is: BSeltzVE01
```

### Date Conversions
Cohesity stores dates in Unix Epoch Microseconds. That's the number of microseconds since midnight on Jan 1, 1970. Several conversion functions have been included to handle these dates.
```python
print api('get','protectionJobs')[0]['creationTimeUsecs']
1533978038503713
  
usecsToDate(1533978038503713)
'2018-08-11 05:00:38'
  
dateToUsecs('2018-08-11 05:00:38')
1533978038000000
  
timeAgo('24','hours')
1534410755000000
```