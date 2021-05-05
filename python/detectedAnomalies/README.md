# Report Helios Detected Ransomeware Anomalies Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script reports Helios Detected Ransomeware Anomalies over the past 30 days.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/detectedAnomalies/detectedAnomalies.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x detectedAnomalies.py
# end download commands
```

## Components

* detectedAnomalies.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./detectedAnomalies.py -u myusername
```

## Note

When prompted for your password, enter the API Key for your Helios account (see Authentication section below).

## Parameters

* -u, --username: username to authenticate to Cohesity cluster

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
