# Pause or Resume Multiple Jobs Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script pauses or resumes future runs of one or more protection jobs.

## Download the script

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pauseResumeJobs/pauseResumeJobs.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x pauseResumeJobs.py
# End download commands
```

## Components

* [pauseResumeJobs.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pauseResumeJobs/pauseResumeJobs.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

To show the state of the jobs:

```bash
# example
./pauseResumeJobs.py -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -j 'My Backup Job 1' \
                     -j 'My Backup Job 2'
# end example
```

To pause some protection jobs:

```bash
# example
./pauseResumeJobs.py -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -j 'My Backup Job 1' \
                     -j 'My Backup Job 2' \
                     -p
# end example
```

To resume the same jobs:

```bash
# example
./pauseResumeJobs.py -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -j 'My Backup Job 1' \
                     -j 'My Backup Job 2' \
                     -r
# end example
```

To pause all active jobs:

```bash
# example
./pauseResumeJobs.py -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -p
# end example
```

The script will output a text file jobsPaused-clusterName.txt of job names that were paused

To resume the same jobs:

```bash
# example
./pauseResumeJobs.py -v mycluster \
                     -u myuser \
                     -d mydomain.net \
                     -l jobsPaused-clusterName.txt \
                     -r
# end example
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -j, --jobName: name of protection job to run (repeat for multiple jobs)
* -l, --jobList: text file containing job names to run (one job per line)
* -p, --pause: pause jobs
* -r, --resume: resume jobs
