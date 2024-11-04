# Simple Job Run Report Example

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script lists protection groups and runs.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/simpleJobRunReport/simpleJobRunReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x simpleJobRunReport.py
# end download commands
```

## Components

* simpleJobRunReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./simpleJobRunReport.py -v mycluster -u myusername -d mydomain.net
# end example
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API Key authentication
* -pwd, --password: (optional) specify password or API key
* -j, --jobname: (optional) filter by job name
* -l, --joblist: (optional) filter by text file list of job names
* -n, --numruns: (optional) number of runs to retrieve at a time (Default is 1000)
