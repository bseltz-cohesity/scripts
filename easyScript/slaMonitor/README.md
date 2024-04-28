# Monitor Missed SLAs using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script finds missed SLAs for recent job runs, and runs on the Cohesity EasyScript app.

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/easyScript/slaMonitor/slaMonitor.zip
# end download commands
```

Unzip the file. We can then use Python or PowerShell to store a password for use by easyScript.

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

Passwords are obfuscated and stored in a file called YWRtaW4. Once the password is stored, create a new zip file of all the files in the folder, for upload to EasyScript.

## Uploading to EasyScript

* In EasyScript, click "Upload a Script"
* Enter a descriptive name for the script
* Select Python 2.7 or 3.7 (both work for this script)
* enter a description (optional)
* enter the arguments (note that all arguments are optional)
* browse and upload our new zip file

## Arguments

* -v, --vip: DNS or IP of the Cluster
* -u, --username: username to connect to cluster
* -d, --domain: (optional) domain of username (default is local)
* -s, --mailserver: (optional) SMTP gateway to forward email through
* -p, --mailport: (optional) defaults to 25
* -f, --sendfrom: (optional) email address to show in the from field
* -t, --sendto: (optional) email addresses to send report to (use repeatedly to add recipients)
* -b, --maxbackuphrs: (optional) defaults to 8
* -r, --maxreplicationhrs: (optional) defaults to 12
* -w, --watch: (optional) all, backup or replication (defaults to all)
