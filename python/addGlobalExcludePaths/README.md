# Add Global Exclude Paths to a File-based Protection Group Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds global exclude paths to file-based physical protection groups.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/addGlobalExcludePaths/addGlobalExcludePaths.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x addGlobalExcludePaths.py
# end download commands
```

## Components

* addGlobalExcludePaths.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./addGlobalExcludePaths.py -v mycluster \
                           -u myuser \
                           -d mydomain.net \
                           -j 'My Backup Job' \
                           -j 'My Backup Job 2' \
                           -e /var/log \
                           -e /home/oracle
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: name of protection job to process (repeat for multiple jobs)
* -l, --joblist: (optional) list of job names in a text file (one per line)
* -e, --exclude: (optional) file path to exclude (repeat for multiple paths)
* -x, --excludefile: (optional) a text file of exclude paths (one per line)
* -o, --overwrite: (optional) overwrite existing exclude paths (default is to append)
