# File Search for Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script searches for a file and displays the results.

## Download the script

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/fileSearch/fileSearch.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x backupNow.py
# End download commands
```

## Components

* [fileSearch.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/fileSearch/fileSearch.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place all files in a folder together. then, run the main script like so:

To list what versions are available:

```bash
./fileSearch.py -v mycluster \
                -u myuser \
                -d mydomain.net \
                -s server1.mydomain.net \
                -j 'My Backup Job' \
                -p /home/myuser/myfile
```

The script will return a numbered list of search results. To see the avaiable versions of a specific result, use the -x parameter with the result number:

```bash
./fileSearch.py -v mycluster \
                -u myuser \
                -d mydomain.net \
                -s server1.mydomain.net \
                -j 'My Backup Job' \
                -p /home/myuser/myfile \
                -x 1
```

## Parameters

* -v, --vip: name of Cohesity cluster to connect to
* -u, --username: short username to authenticate to the cluster
* -d, --domain: (optional) active directory domain of user (default is local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password for Cohesity user
* -p, --filepath: full or partial path of file to search for
* -s, --sourceserver: (optional) filter on server or vm name
* -j, --jobname: (optional) filter on job name
* -x, --showversions: (optional) show available versions for a specific result
* -t, --jobtype: (optional) filter on server type (Physical or VMware)
