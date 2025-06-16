# Restore VM Files using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script restores files from a VMware VM backup.

## Components

* [restoreVMFiles.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreVMFiles/restoreVMFiles.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreVMFiles/restoreVMFiles.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreVMFiles.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./restoreVMFiles.py -v mycluster \
                    -u myusername \
                    -d mydomain.net \
                    -s myvm1 \
                    -t myvm2 \
                    -n /home/myusername/file1 \
                    -n /home/myusername/file2 \
                    -p /tmp/restoretest/ \
                    -f '2020-04-18 18:00:00' \
                    -w
# end example
```

## Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (defaults to helios.cohesity.com)
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) hard code password (uses stored password by default)
* -c, --clustername: (optional) Helios connected cluster to connect to (when connected to Helios)
* -s, --sourcevm: name of source server
* -t, --targetvm: (optional) name of target server (defaults to source server)
* -n, --filename: (optional) path of file to recover (repeat parameter for multiple files)
* -f, --filelist: (optional) text file containing multiple files to restore
* -p, --restorepath: (optional) path to restore files on target server (defaults to original location)
* -r, --runid: (optional) select backup version with this job run ID
* -l, --showversions: (optional) show available run IDs and dates
* -o, --olderthan: (optional) restore from last version prior to this date, e.g. '2021-01-30 23:00:00'
* -y, --daysago: (optional) restore from last backup X days ago (1 = last night, 2 = night before last)
* -w, --wait: (optional) wait for completion and report status
* -m, --restoremethod: (optional) ExistingAgent, AutoDeploy, or VMTools (default is AutoDeploy)
* -vu, --vmuser: (optional) required for AutoDeploy and VMTools restore methods, e.g. 'mydomain.net\myuser'
* -vp, --vmpwd: (optional) will be prompted if required and omitted
* -x, --noindex: (optional) use if VM is not indexed, file paths must be exact case
* -k, --taskname: (optional) set name of recovery task
* -j, --jobname: (optional) filter on protection group name

## File Names and Paths

File names must be specified as absolute paths, like:

* Linux: '/home/myusername/file1'
* Windows: 'C:\Users\MyUserName\Documents\File1' or '/C/Users/MyUserName/Documents/File1'

## Selecting a Point in Time

By default, the latest backup will be used. You can use one of the following to select a different point in time:

-l, --showversions: this switch will display the backup run dates and IDs that are available to select. Once you find the date you are looking for, you can specify that run ID using the -runId parameter.

-r, --runid: specify a runId (use -showVersions to see the list of available runIds).

-o, --olderthan: specify a date in format like 'YYYY-MM-DD HH:mm:ss' e.g. '2021-01-30 23:01:45'. The script will select the latest point in time before the specified date.

-x, --daysago: the script will select the latest point in time that is X days ago. Yesterday is 1 day ago, so -daysAgo 1 will select the last backup that ran yesterday. -daysAgo 2 will select the last backup that occurred the day before yesterday, and so on.

## The Python Helper Module - pyhesity.py

Please find more info on the pyhesity module here: <https://github.com/cohesity/community-automation-samples/tree/main/python>
