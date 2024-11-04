# Resolve SQL Log Chain Breaks and AAG Failovers Across Helios Clusters using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script detects SQL Log backup failures due to log chain breaks and AAG failovers, and run the failed protection group to rest the log chain.

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/easyScript/heliosAagMonitor/heliosAagMonitor.zip
# end download commands
```

## Getting a Password for Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again).

Use this API key as the password.

## Uploading to EasyScript

* In EasyScript, click "Upload a Script"
* Enter a descriptive name for the script
* Select Python 2.7 or 3.7 (both work for this script)
* enter a description (optional)
* enter the arguments
* browse and upload the zip file

## Example Arguments

```bash
# example arguments
-u myuser@mydomain.net -pwd xxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -ms mail.mydomain.net -to myuser@mydomain.net -fr helios@mydomain.net
# end example
```

## Authentication Arguments

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm clusters to connect to (repeat for multiple, default is all clusters)

## Other Arguments

* -ms, --mailserver: (optional) SMTP gateway to forward email through
* -pp, --mailport: (optional) defaults to 25
* -fr, --sendfrom: (optional) email address to show in the from field
* -to, --sendto: (optional) email addresses to send report to (repeat for multple recipients)
* -as, --alwayssend: (optional) send email even if no issues detected
