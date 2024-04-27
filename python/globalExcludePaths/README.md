# Add Global Exclude Paths to File-based Protection Jobs Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script adds physical linux servers to a file-based protection job.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/globalExcludePaths/globalExcludePaths.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x globalExcludePaths.py
# end download commands
```

## Components

* [globalExcludePaths.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/globalExcludePaths/globalExcludePaths.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./globalExcludePaths.py -v mycluster \
                        -u myuser \
                        -d mydomain.net \
                        -j 'My Backup Job' \
                        -e /home/oracle
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobname: (optional) one or more protection jobs (comma separated)
* -l, --joblist: (optional) text file of job names (one per line)
* -e, --exclusions: (optional) file path to exclude (use multiple times for multiple paths)
* -x, --excludelist: (optional) a text file full of exclude file paths (one per line)
* -r, --replacerules: (optional) erase existing exclusions
