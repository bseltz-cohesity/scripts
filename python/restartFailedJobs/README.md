# Restart Failed Jobs using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script restarts jobs if the last run was not successful. Output is logged to a text file.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restartFailedJobs/restartFailedJobs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restartFailedJobs.py
# end download commands
```

## Components

* [restartFailedJobs.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restartFailedJobs/restartFailedJobs.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./restartFailedJobs.py -v mycluster1 \
                       -v mycluster2 \
                       -u myuser \
                       -d mydomain.net \
                       -r
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to (repeat for multiple clusters)
* -l, --clusterlist: text file of cluster names to connect to (one per line)
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -c, --canceled: (optional) restart canceled jobs
* -n, --hoursback: (optional) number of hours to look back (default is 24)
* -r, --restart: (optional) perform restarts (display only is the default)
* -t, --jobtype: (optional) filter on a specific job type (e.g. VMware, SQL, etc.)
* -j, --jobname: (optional) name of job to replicate (repeat for multiple jobs or use joblist)
* -l, --joblist: (optional) text file of job names to include (one per line) default is all failed jobs
