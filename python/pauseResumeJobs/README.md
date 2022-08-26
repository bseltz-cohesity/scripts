# Pause or Resume Multiple Jobs Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script pauses or resumes future runs of one or more protection jobs.

## Download the script

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pauseResumeJobs/pauseResumeJobs.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x pauseResumeJobs.py
# End download commands
```

## Components

* pauseResumeJobs.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

To pause some protection jobs, place all files in a folder together. then, run the main script like so:

```bash
./pauseResumeJobs.py -v mycluster -u myuser -d mydomain.net -j 'My Backup Job 1' -j 'My Backup Job 2'
```

To resume the same jobs, add the -r switch:

```bash
./pauseResumeJobs.py -v mycluster -u myuser -d mydomain.net -j 'My Backup Job 1' -j 'My Backup Job 2' -r
```

## Parameters

* -v, --vip: name of Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: short username to authenticate to the cluster (default is helios)
* -d, --domain: active directory domain of user (default is local)
* -i, --useApiKey: use API key for authentication
* -p, --password: send password in clear text (not recommended, use default stored password behavior)
* -j, --jobName: name of protection job to run (repeat for multiple jobs)
* -l, --jobList: text file containing job names to run (one job per line)
* -r, --resume: resume jobs (pause jobs if omitted)
