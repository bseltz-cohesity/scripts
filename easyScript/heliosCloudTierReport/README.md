# Report CloudTier Usage on Helios Clusters using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script generates a report of cloudTier usage across all clusters connected to Helios.

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/easyScript/heliosCloudTierReport/heliosCloudTierReport.zip
# end download commands
```

## Getting an API Key for Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again).

## Uploading the script to EasyScript

* In EasyScript, click "Upload a Script"
* Enter a descriptive name for the script
* Select Python 2.7 or 3.7 (both work for this script)
* enter a description (optional)
* enter the arguments (see below)
* browse and upload the zip file

## Arguments

* -k, --apikey: apikey used for authentication
* -n, --units: (optional) GiB or TiB (default is TiB)
* -s, --mailserver: SMTP gateway to forward email through
* -p, --mailport: (optional) defaults to 25
* -f, --sendfrom: email address to show in the from field
* -t, --sendto: email addresses to send report to (use repeatedly to add recipients)

For example: you can have the script send a report via email using the folllowing arguments:

```bash
-k xxxxxxxxxxxxxxx -s smtp.mydomain.net -t myemail.mydomain.net -f easyscript.mydomain.net
```
