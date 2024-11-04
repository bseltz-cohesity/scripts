# Report Backed Up File Systems using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script generates a report of volumes / file systems of physical and virtual servers that have been protected by Cohesity. The script will generate an html report and also generate a CSV file.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/backedUpFSReport/backedUpFSReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x backedUpFSReport.py
# end download commands
```

## Components

* backedUpFSReport.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./backedUpFSReport.py -v mycluster \
                      -u myusername \
                      -d mydomain.net
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to (repeat for multiple clusters)
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -i, --useApiKey: (optional) use API key for authentication
* -pwd: --password: (optional) use password from command line instead of stored password
* -s, --search: (optional) limit search to objectnames that match string
* -e, --exactmatch: (optional) object name must exactly match search string
