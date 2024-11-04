# Resolve SQL Log Chain Breaks and AAG Failovers Across Helios Clusters using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script detects SQL Log backup failures due to log chain breaks and AAG failovers, and run the failed protection group to rest the log chain.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/aagFailoverMonitor/aagFailoverMonitor.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x aagFailoverMonitor.py
# end download commands
```

## Components

* aagFailoverMonitor.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example arguments
./aagFailoverMonitor.py -u myuser@mydomain.net
# end example
```

## Authentication Arguments

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm clusters to connect to (repeat for multiple, default is all clusters)

## Other Arguments

* -ms, --mailserver: (optional) SMTP gateway to forward email through
* -pp, --mailport: (optional) defaults to 25
* -fr, --sendfrom: (optional) email address to show in the from field
* -to, --sendto: (optional) email addresses to send report to (repeat for multple recipients)
* -as, --alwayssend: (optional) send email even if no issues detected
* -f, --fullbackup: (optional) perform full backup (default is incremental)
