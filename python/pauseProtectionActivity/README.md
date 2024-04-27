# Pause or Resume Protection Activity Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script pauses (or resumes) protection groups, replication, archival, indexing and garbage collection activity with the goal of optimizing performance for restore operations.

## Download the script

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pauseProtectionActivity/pauseProtectionActivity.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x pauseProtectionActivity.py
# End download commands
```

## Components

* [pauseProtectionActivity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pauseProtectionActivity/pauseProtectionActivity.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

To pause protection activity:

```bash
# example
./pauseProtectionActivity.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \
                             -p
# end example
```

To resume protection activity:

```bash
# example
./pauseProtectionActivity.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \
                             -r
# end example
```

To cancel running jobs only:

```bash
# example
./pauseProtectionActivity.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \
                             -c
# end example
```

To pause garbage collection only:

```bash
# example
./pauseProtectionActivity.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \
                             -p \
                             -g
# end example
```

To resume garbage collection only:

```bash
# example
./pauseProtectionActivity.py -v mycluster \
                             -u myuser \
                             -d mydomain.net \
                             -r \
                             -g
# end example
```

The script will output a few files for reference:

* a text file jobsPaused-clusterName.txt of job names that were paused
* a text file archiveSettings-clusterName.txt pf the previous archival settings
* a detailed log file pauseLog-clusterName-date.txt

## Authentication Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -p, --pause: (optional) pause activity
* -r, --resume: (optional) resume activity
* -c, --cancelrunsonly: (optional) cancel running jobs only (skip all other steps)
* -g, --stopgconly: (optional) pause/resume garbage collection only (skip all other steps)
* -l, --nojoblist: (optional) resume all paused protection jobs (only needed if jobsPaused-xxxx.txt is lost)
* -o, --outpath: (optional) path to write output files (default is '.')
