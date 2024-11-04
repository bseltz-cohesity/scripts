# List Old Snapshots using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script will list local snapshots.

## Components

* [oldSnapList.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/oldSnapList/oldSnapList.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/oldSnapList/oldSnapList.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x oldSnapList.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./oldSnapList.py -v mycluster \
                 -u myuser \
                 -d mydomain.net \
                 -j 'My Backup Job'
# end example
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: (optional) show snapshots for only this job (default is all jobs)
* -o, --olderthan: (optional) show snapshots older than X days (default is 0)
* -n, --numruns: (optional) slurp X runs at a time (default is 100)
