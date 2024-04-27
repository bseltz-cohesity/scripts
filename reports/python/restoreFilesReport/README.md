# Report on File Restores using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script creates a report of file-based restores. Output is saved to HTML and CSV files.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/restoreFilesReport/restoreFilesReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreFilesReport.py
# end download commands
```

## Components

* restoreFilesReport.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./restoreFilesReport.py -v mycluster \
                        -u myusername \
                        -d mydomain.net
```

## Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (defaults to helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (defaults to helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd: --password: (optional) use password from command line instead of stored password
* -c, --clustername: (optional) cluster to connect to when connecting through Helios
* -d, --days: (optional) number of days to inspect (defaults to 31)
