# Report Helios Detected Ransomeware Anomalies Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script reports Helios Detected Ransomeware Anomalies and forwards them to syslog.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/detectedAnomalies/detectedAnomalies.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x detectedAnomalies.py
# end download commands
```

## Components

* [detectedAnomalies.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/detectedAnomalies/detectedAnomalies.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./detectedAnomalies.py -u myusername
```

## Note

When prompted for your password, enter the API Key for your Helios account (see Authentication section below).

## Parameters

* -v, --vip: (optional) mcm or helios (defaults to helios.cohesity.com)
* -u, --username: (optional) username to authenticate (defaults to helios)
* -d, --domain: (optional) defaults to local
* -pwd, --password: (optional) will use cached password if omitted
* -m, --minimumstrength: (optional) defaults to 10
* -y, --days: (optional) number of days to look back (default is 7)
* -f, --maxlogfilesize: (optional) default is 10000 lines

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
> apiauth(username='myusername', updatepw=True)
Enter your password: *********************
```
