# Get Physical Server Directive File Path Backup History

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script reports directive files used for physical server file-based backups over the past X days.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/directiveBackupHistoryReport/directiveBackupHistoryReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x directiveBackupHistoryReport.py
# end download commands
```

## Components

* directiveBackupHistoryReport.py: the main powershell script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To get the backup paths for one cluster:

```bash
./directiveBackupHistoryReport.py -v mycluster \
                                  -u myusername \
                                  -d mydomain.net
```

To get the backup paths for multiple clusters:

```bash
./directiveBackupHistoryReport.py -v mycluster1 \
                                  -v mycluster2 \
                                  -u myusername \
                                  -d mydomain.net
```

To get the backup paths for all helios clusters:

```bash
./directiveBackupHistoryReport.py -u myusername@mydomain.net
```

To get the backup paths for selected helios clusters:

```bash
./directiveBackupHistoryReport.py -u myusername@mydomain.net \
                                  -c mycluster1 \
                                  -c mycluster2
```

## Parameters

* -v, --vip: (optional) one or more names or IPs of Cohesity clusters to connect to (repeat for multiple) default is helios.cohesity.com
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) one or more helios/mcm clusters to connect to (repeat for multiple)
* -m, --mfacode: (optional) MFA code for authentication
* -y, --days: (optional) number of days to report
* -n, --numruns: (optional) max number of runs to report (default is 1000)
