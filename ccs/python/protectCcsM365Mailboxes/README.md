# Protect Ccs M365 Mailboxes Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script protects Ccs M365 Mailboxes.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/protectCcsM365Mailboxes/protectCcsM365Mailboxes.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x protectCcsM365Mailboxes.py
# end download commands
```

## Components

* [protectCcsM365Mailboxes.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/protectCcsM365Mailboxes/protectCcsM365Mailboxes.py): the main powershell script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./protectCcsM365Mailboxes.py -u myuser \
                               -r us-east-2 \
                               -l ./mailboxlist.txt \
                               -p mypolicy \
                               -s myaccount.onmicrosoft.com
```

## Parameters

* -u, --username: (optional) username to authenticate to Ccs (used for password storage only)
* -r, --region: Ccs region to use
* -s, --sourcename: name of registered M365 protection source
* -p, --policyname: name of protection policy to use
* -m, --mailboxname: (optional) mailbox name or SMTP address to protect (repeat for multiple)
* -l, --mailboxlist: (optional) text file of mailbox names or SMTP addresses to protect (one per line)
* -tz, --timezone: (optional) time zone for new job (default is US/Eastern)
* -st, --starttime: (optional) start time for new job (default is 21:00)
* -is, --incrementalsla: (optional) incremental SLA minutes (default is 60)
* -fs, --fullsla: (optional) full SLA minutes (default is 120)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
