# Cancel Ccs Protection Runs using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script script cancels running protection activities.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/cancelCcsProtectionRuns/cancelCcsProtectionRuns.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x cancelCcsProtectionRuns.py
# end download commands
```

## Components

* [cancelCcsProtectionRuns.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/cancelCcsProtectionRuns/cancelCcsProtectionRuns.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

Cancel the backup of a VM:

```bash
./cancelCcsProtectionRuns.py -o myvm1
```

Cancel the backup of a SQL Server (all databases):

```bash
./cancelCcsProtectionRuns.py -s sqlserver1.mydomain.net
```

Cancel the backup of a SQL Database:

```bash
./cancelCcsProtectionRuns.py -s sqlserver1.mydomain.net -o MSSQLSERVER\mydb
```

## Parameters

* -u, --username: (optional) username to authenticate to Ccs (used for password storage only)
* -pwd, --password: (optional) API key for authentication
* -np, --noprompt: (optional) do not prompt for API key, exit if not authenticated
* -r, --region: (optional) Ccs region to use
* -o, --objectName: (optional) name of protected object to backup (e.g. name of VM, name of database)
* -s, --sourceName: (optional) name of registered source (e.g. name of SQL Server)
* -e, --environment: (optional) filter by specific environment (e.g. kO365)
* -t, --subtype: (optional) filter by specific subtype (e.g. kO365OneDrive)
* -w, --wait: (optional) wait for cancelations to complete
* -z, --sleeptime: (optional) sleep for X seconds while waiting (default is 30)

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
