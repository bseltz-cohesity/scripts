# Helios Old Snapshot Report for EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script generates a report of queued archive tasks from Helios and runs on the Cohesity EasyScript app.

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/easyScript/heliosOldSnapshotReport/heliosOldSnapshotReport.zip
# end download commands
```

## Getting an API Key for Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again).

## Uploading to EasyScript

* In EasyScript, click "Upload a Script"
* Enter a descriptive name for the script
* Select Python 2.7 or 3.7 (both work for this script)
* enter a description (optional)
* enter the arguments
* browse and upload the zip file

## Arguments

* -k, --apikey
* -d, --daystokeep: number of days of snapshots to keep
* -c, --clustername: (optional) limit to single cluster (default is all helios clusters)
* -e, --expire: (optional) expire old snapshots (default is to report only)
* -b, --daysback: (optional) days of history to interrogate (default is 730)
* -n, --numruns: (optional) page size for retrieving runs (default is 1000)
* -s, --mailserver: SMTP gateway to forward email through
* -p, --mailport: (optional) defaults to 25
* -f, --sendfrom: email address to show in the from field
* -t, --sendto: email addresses to send report to (use repeatedly to add recipients)

To report snapshots older than 31 days:

```bash
-k xxxxxxxxxxxxxxx -s smtp.mydomain.net -t myemail.mydomain.net -f easyscript.mydomain.net -d 31
```

To expire snapshots older than 31 days, add the -e switch:

```bash
-k xxxxxxxxxxxxxxx -s smtp.mydomain.net -t myemail.mydomain.net -f easyscript.mydomain.net -d 31 -e
```
