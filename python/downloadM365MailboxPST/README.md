# Download M365 Mailbox as PST Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script downloads an M365 mailbox backup as a PST.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/downloadM365MailboxPST/downloadM365MailboxPST.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x downloadM365MailboxPST.py
# end download commands
```

## Components

* downloadM365MailboxPST.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To create a new protection group:

```bash
./downloadM365MailboxPST.py -v mycluster \
                            -u myuser \
                            -d mydomain.net \
                            -s someuser1@mydomain.onmicrosoft.com \
                            -s someuser2@mydomain.onmicrosoft.com \
                            -f ./mypst.zip \
                            -w bosco
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
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -s, --sourceusername: (optional) name of mailbox user to download (repeat for multiple)
* -l, --sourceuserlist: (optional) text file of mailbox users to download (one per line)
* -f, --filename: (optional) zip file name to download (default is pst.zip)
* -r, --recoverdate: (optional) restore from on or before this date (e.g. '2024-05-11 23:45:00')
* -w, --pstpassword: (optional) password to set on PSTs (will be prompted if omitted)
* -x, --continueonerror: (optional) continue processing if a mailbox is not found (exit by default)
