# Archive End Of Month using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script archives the last backup of the month.

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/easyScript/archiveEndOfMonth/archiveEndOfMonthES.zip
# end download commands
```

Unzip the file. We can then use Python or PowerShell to store a password for use by easyScript.

## Storing the Password with Python

Open a terminal or command prompt and change directory to where the files were unzipped. Then run the command:

```bash
python storePassword.py -v mycluster -u myuser -d mydomain.net
Enter password for mydomain.net/myuser at mycluster: ************************************
```

## Storing the Password with PowerShell

```powershell
.\storePassword.ps1 -vip mycluster -username myuser -domain mydomain.net
Enter password for mydomain.net/myuser at mycluster: ************************************
```

Once the password is stored, create a new zip file of all the files in the folder, for upload to EasyScript.

## Uploading to EasyScript

* In EasyScript, click "Upload a Script"
* Enter a descriptive name for the script
* Select Python 2.7 or 3.7 (both work for this script)
* enter a description (optional)
* enter the arguments
* browse and upload our new zip file

## Example arguments

-v mycluster -u myusername -d mydomain.net -j "my job" -t mys3target -k 180

## Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: active directory domain of user (default is local)
* -j, --jobname: name of job to archive (repeat for multiple jobs)
* -k, --keepFor: days to keep the archive in retention
* -t, --target: name of external target to archive to
