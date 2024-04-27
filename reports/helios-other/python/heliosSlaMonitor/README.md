# Monitor Missed SLAs Across Helios Clusters using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script finds missed SLAs for recent job runs

## Components

* heliosSlaMonitor.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/helios-other/python/heliosSlaMonitor/heliosSlaMonitor.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x heliosSlaMonitor.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./heliosSlaMonitor.py
```

If you'd like to send the report via email, include the mail-related parameters:

```bash
./heliosSlaMonitor.py -s mysmtpserver -t toaddr@mydomain.net -f fromaddr@mydomain.net
```

## Parameters

* -v, --vip: (optional) DNS or IP of the Helios endpoint (defaults to helios.cohesity.com)
* -u, --username: (optional) username to store helios API key (defaults to helios)
* -d, --domain: (optional) domain of username to store helios API key (default is local)
* -s, --mailserver: (optional) SMTP gateway to forward email through
* -p, --mailport: (optional) defaults to 25
* -f, --sendfrom: (optional) email address to show in the from field
* -t, --sendto: (optional) email addresses to send report to (use repeatedly to add recipients)
* -b, --maxbackuphrs: (optional) defaults to 8
* -r, --maxreplicationhrs: (optional) defaults to 12
* -w, --watch: (optional) all, backup or replication (defaults to all)

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
