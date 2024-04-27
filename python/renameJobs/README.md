# Rename Multiple Jobs Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script renames one or more protection jobs.

## Download the script

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/renameJobs/renameJobs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x renameJobs.py
# End download commands
```

## Components

* [renameJobs.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/renameJobs/renameJobs.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

To rename a protection job, place all files in a folder together, then run the main script like so:

```bash
./renameJobs.py -v mycluster -u myuser -d mydomain.net -j 'My Backup Job 1' -n 'My Backup Job 2' -c
```

To rename a list of jobs, create a CSV file with existing job names in the first column, and the new job names in the second column. Then run the script like so:

```bash
./renameJobs.py -v mycluster -u myuser -d mydomain.net -l myjoblist.csv -c
```

## Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: active directory domain of user (default is local)
* -i, --useApiKey: use API key for authentication
* -p, --password: send password in clear text (not recommended, use default stored password behavior)
* -j, --jobName: name of protection job to run
* -n, --newName: new name for protection job
* -l, --jobList: text file containing job names (one job per line in the form: oldname,newname)
* -c, --commit: perform deletions (test mode only if omitted)
