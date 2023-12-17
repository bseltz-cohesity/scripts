# See if a Protection Job is Running using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script determines if a protection job is running or not. If it is running, it will exit with exit code 1, otherwise it will exit with exit code 0.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/jobRunning/jobRunning.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x jobRunning.py
# end download commands
```

## Components

* [jobRunning.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/jobRunning/jobRunning.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To get the status of the job:

```bash
./jobRunning.py -v mycluster \
                -u myusername \
                -d mydomain.net \
                -j myjob
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -j, --jobname: name of job to display (repeat parameter for multiple jobs)
