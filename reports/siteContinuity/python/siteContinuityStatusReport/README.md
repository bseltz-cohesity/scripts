# Generate SiteContinuity Status Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a SiteContinuity status report and outputs to HTML and CSV files.

## Components

* siteContinuityStatusReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/siteContinuity/python/siteContinuityStatusReport/siteContinuityStatusReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x siteContinuityStatusReport.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./siteContinuityStatusReport.py  -u myusername@mydomain.net
```

## Parameters

* -u, --username: (optional) defaults to helios
* -s, --startdate: (optional) specify start of date range
* -e, --enddate: (optional) specify end of date range
* -t, --thismonth: (optional) set date range to this month
* -l, --lastmonth: (optional) set date range to last month
* -y, --days: (optional) set date range to last X days (default is 31)
* -n, --drplanname: (optional) filter on DR Plan name
* -p, --datapoolname: (optional) filter on Datapool name

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

Please see here for more information: <https://github.com/cohesity/community-automation-samples/tree/main/python#cohesity-rest-api-python-examples>

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

If you enter the wrong password, you can re-enter the password like so:

```python
> from pyhesity import *
> apiauth(updatepw=True)
Enter your password: *********************
```
