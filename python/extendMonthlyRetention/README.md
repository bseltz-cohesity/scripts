# Extend Monthly Retention using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script extends the retention of a monthly snappshot.

## Components

* [extendMonthlyRetention.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/extendMonthlyRetention/extendMonthlyRetention.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

## Download The Scripts

The script is designed to run from the Cohesity cluster. To download and install the script, SSH into the cohesity cluster and run the following commands to download the scripts:

```bash
# begin download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/extendMonthlyRetention/extendMonthlyRetention.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x extendMonthlyRetention.py
# end download commands
```

Place the files in a folder together and run the main script like so:

```bash
./extendMonthlyRetention.py -s mycluster \
                            -u myusername \ 
                            -d mydomain.net \
                            -j 'my protection job' \
                            -m -1 \
                            -k 365 \
                            -e
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -j, --jobName: name of protection job to process
* -m, --dayOfMonth: (optional) day of month to extend monthly snapshot (default is 1)
* -k --daysToKeep: number of days (from backup date) to keep the backup
* -e, --extend: (optional) extend the retention (otherwise test/show only)
