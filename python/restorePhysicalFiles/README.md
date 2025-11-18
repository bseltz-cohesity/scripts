# Restore Files from Physical Server Backups using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script restores files from a Cohesity physical server backup.

## Components

* [restorePhysicalFiles.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restorePhysicalFiles/restorePhysicalFiles.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restorePhysicalFiles/restorePhysicalFiles.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restorePhysicalFiles.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./restorePhysicalFiles.py -v mycluster \
                         -u myusername \
                         -d mydomain .net \
                         -s server1.mydomain.net \
                         -t server2.mydomain.net \
                         -n /home/myusername/file1 \
                         -n /home/myusername/file2 \
                         -p /tmp/restoretest/ \
                         -o '2020-04-18 18:00:00' \
                         -w
# end example
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -org, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Basic Parameters

* -s, --sourceserver: name of source server
* -t, --targetserver: (optional) name of target server (defaults to source server)
* -n, --filename: (optional) path of file to recover (repeat parameter for multiple files)
* -f, --filelist: (optional) text file containing multiple files to restore (one per line)
* -p, --restorepath: (optional) path to restore files on target server (defaults to original location)

## Other Parameters

* -l, --listruns: (optional) list available runs and exit
* -r, --runid: (optional) select backup version with this run ID
* -o, --olderthan: (optional) restore from on or before this date
* -w, --wait: (optional) wait for completion and report status
* -k, --taskname: (optional) set name of recovery task
* -z, --sleeptimeseconds: (optional) sleep X seconds between status queries (default is 30)
* -j, --jobname: (optional) narrow search by job name
* -x, --overwrite: (optional) overwrite existing files
* -a, --fromarchive: (optional) restore from archive

## Backup Versions

By default, the script will search for each file and restore it from the newest version available for that file. You can narrow the date range that will be searched by using the --start and --end parameters.

Using the --runid or --latest parameters will cause the script to try to restore all the requested files at once (in one recovery task), from one backup version.

## File Names and Paths

File names must be specified as absolute paths like:

* Linux: /home/myusername/file1
* Windows: c:\Users\MyUserName\Documents\File1 or C/Users/MyUserName/Documents/File1

## Restoring a Folder or All Children of a Folder

You can restore an entire folder, like so:

```bash
# example
./restorePhysicalFiles.py -v mycluster \
                  -u myusername \
                  -d mydomain .net \
                  -s server1.mydomain.net \
                  -n /folder1/ \
                  -p /folder2/ \
                  -w
# end example
```

The above will result in the folder being restored to /folder2/folder1

If You wanted the contents of folder1 to land directly in /folder2, then after the restore, on the host you can `mv /folder2/folder1/* /folder2 && rmdir /folder2/folder1`

## The Python Helper Module - pyhesity.py

Please find more info on the pyhesity module here: <https://github.com/cohesity/community-automation-samples/tree/main/python>
