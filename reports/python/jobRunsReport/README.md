# Get Job Runs Status using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script gets the stats for job runs and outputs to a CSV file.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/jobRunsReport/jobRunsReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x jobRunsReport.py
# end download commands
```

## Components

* jobRunsReport.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./jobRunsReport.py -v mycluster \
                   -u myusername \
                   -d mydomain.net \
                   -j 'my job'
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd: --password: (optional) use password from command line instead of stored password
* -j, --jobname: name of job to inspect
* -n, --numruns: (optional) number of runs to gather at a a time (default is 100)
* -y, --days: (optional) number of days to retrieve (default is 7)
* -units, --units: (optional) MB or GB (default is MB)
