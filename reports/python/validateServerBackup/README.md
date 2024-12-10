# Validate Server Backups using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script validates backups for physical and virtual servers. The script will generate an html report and send it to email recipients. The validation process instructs the cluster to mount the latest backup volume and retrieve a directory listing. If the directory is readable, the backup is considered valid.

Report colors: if the last backup is not readable, the item will be shown in red. If the last backup is old, the item will be shown in purple (see -wh, --warninghours below).

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/validateServerBackup/validateServerBackup.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x validateServerBackup.py
# end download commands
```

## Components

* validateServerBackup.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./validateServerBackup.py -v mycluster -u myusername -d mydomain.net
# end example
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --servername: (optional) name of server to include (repeat for multiple)
* -l, --serverlist: (optional) text file of server names to include (one per line)
* -of, --outfolder: (optional) folder to save output file (default is '.')
* -wh, --warninghours: (optional) color purple if latest backup is older than X hours (default is 48)
* -p, --pagesize: (optional) page size for API queries (default is 1000)
* -ms, --mailserver: (optional) SMTP gatewsy to send mail through
* -mp, --mailport: (optional) SMTP gateway port (default is 25)
* -to, --sendto: (optional) email address to send report to (repeat for multiple)
* -fr, --sendfrom: (optional) email address to send from
