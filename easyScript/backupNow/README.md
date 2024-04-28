# Run a ProtectionJob using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script finds recent failed jobs, and runs on the Cohesity EasyScript app.

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/easyScript/backupNow/backupNowES.zip
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
* enter the arguments (note that all arguments are optional)
* browse and upload our new zip file

## Basic Parameters

* -j, --jobname: name of protection job to run

## Optional Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: active directory domain of user (default is local)
* -i, --useApiKey: use API key for authentication
* -o, --objectname: name of object to backup (repeat this parameter for multiple objects)
* -k, --keepLocalFor: days to keep local snapshot (default is 5 days)
* -a, --archiveTo: name of archival target to archive to
* -ka, --keepArchiveFor: days to keep in archive (default is 5 days)
* -r, --replicateTo: name of remote cluster to replicate to
* -kr, --keepReplicaFor: days to keep replica for (default is 5 days)
* -e, --enable: enable a paused job before running, then disable when done
* -w, --wait: wait for backup run to complete and report result
* -s, --waitforstart: wait for existing job run to complete before starting
* -t, --backupType: choose one of kRegular, kFull or kLog backup types. Default is kRegular (incremental)

## Using -o (--objectname) Parameter

If the -o parameter is omitted, all objects within the specified job are backed up. To select specific objects to backup, us the -o parameter. The format of the object name varies per object type. For example:

* -o myvm1 (VM)
* -o oracle1.mydomain.net/testdb (Oracle)
* -o sql1.mydomain.net/MSSQLSERVER/proddb (SQL)

Repeat the parameter to include multiple objects.
