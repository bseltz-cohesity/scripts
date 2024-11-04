# Monitor Job Failures Across Helios Clusters using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script finds recent failed jobs, and runs on the Cohesity EasyScript app.

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/easyScript/heliosJobFailures/heliosJobFailuresES.zip
# end download commands
```

Unzip the file. We can then use Python or PowerShell to store a password for use by easyScript.

## Getting a Password for Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again).

Use this API key as the password.

## Storing the Password with Python

Open a terminal or command prompt and change directory to where the files were unzipped. Then run the command:

```bash
python storePassword.py
Enter password for local/helios at helios.cohesity.com: ************************************
```

## Storing the Password with PowerShell

```powershell
.\storePassword.ps1
Enter password for local/helios at helios.cohesity.com: ************************************
```

Once the password is stored, create a new zip file of all the files in the folder, for upload to EasyScript.

## Uploading to EasyScript

* In EasyScript, click "Upload a Script"
* Enter a descriptive name for the script
* Select Python 2.7 or 3.7 (both work for this script)
* enter a description (optional)
* enter the arguments (note that all arguments are optional)
* browse and upload our new zip file

## Arguments

* -v, --vip: (optional) DNS or IP of the Helios endpoint (defaults to helios.cohesity.com)
* -u, --username: (optional) username to store helios API key (defaults to helios)
* -d, --domain: (optional) domain of username to store helios API key (default is local)
* -s, --mailserver: (optional) SMTP gateway to forward email through
* -p, --mailport: (optional) defaults to 25
* -f, --sendfrom: (optional) email address to show in the from field
* -t, --sendto: (optional) email addresses to send report to (use repeatedly to add recipients)

For example: you can have the script send a report via email using the folllowing arguments:

```bash
-s smtp.mydomain.net -t myemail.mydomain.net -f easyscript.mydomain.net
```
