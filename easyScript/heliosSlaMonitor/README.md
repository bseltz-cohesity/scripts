# Monitor Missed SLAs Across Helios Clusters using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script finds missed SLAs for recent job runs, and runs on the Cohesity EasyScript app.

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/easyScript/heliosSlaMonitor/heliosSlaMonitorES.zip
# end download commands
```

Upload the zip file to easyScript and specify the arguments, like:

```bash
-pw xxxxxxxxxxxx
```

Where -pw is the helios API key (see below). If you'd like to send the report via email, the provide the mail-related arguments:

```bash
-pw xxxxxxxxxxxx -s mysmtpserver -t toaddr@mydomain.net -f fromaddr@mydomain.net
```

## Parameters

* -v, --vip: (optional) DNS or IP of the Helios endpoint (defaults to helios.cohesity.com)
* -u, --username: (optional) username to store helios API key (defaults to helios)
* -d, --domain: (optional) domain of username to store helios API key (default is local)
* -pw, --password: use the helios API key as the password (see below)
* -s, --mailserver: (optional) SMTP gateway to forward email through
* -p, --mailport: (optional) defaults to 25
* -f, --sendfrom: (optional) email address to show in the from field
* -t, --sendto: (optional) email addresses to send report to (use repeatedly to add recipients)
* -b, --maxbackuphrs: (optional) defaults to 8
* -r, --maxreplicationhrs: (optional) defaults to 12
* -w, --watch: (optional) all, backup or replication (defaults to all)

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again).

Use this API key as the password (-pw) above
