# Monitor Missed SLAs in CCS Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script reports Missed SLAs in CCS.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/ccsSlaMonitor/ccsSlaMonitor.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x ccsSlaMonitor.py
# end download commands
```

## Components

* [ccsSlaMonitor.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/ccsSlaMonitor/ccsSlaMonitor.py): the main powershell script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To check CCS for missed SLA's in the past 24 hours:

```bash
./ccsSlaMonitor.py -u myuser.mydomain.net
```

To specify the max number of minutes for log backups to generate a missed SLA warning:

```bash
./ccsSlaMonitor.py -u myuser.mydomain.net -l 15
```

To send the report via email:

```bash
./ccsSlaMonitor.py -u myuser.mydomain.net -l 15 \
                   -m smtp.mydomain.net \
                   -f me@mydomain.net \
                   -t thisteam@mydomain.net \
                   -t thatteam@mydomain.net
```

## Parameters

* -u, --username: (optional) username to authenticate to Ccs (used for password storage only)
* -pwd, --password: (optional) API key for authentication
* -np, --noprompt: (optional) do not prompt for API key, exit if not authenticated
* -l, --logwarningminutes: (optional) warn for log backups that took longer than X minutes (default is 60)
* -m, --mailserver: SMTP gateway to forward email through
* -p, --mailport: (optional) defaults to 25
* -f, --sendfrom: email address to show in the from field
* -t, --sendto: email addresses to send report to (use repeatedly to add recipients)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
