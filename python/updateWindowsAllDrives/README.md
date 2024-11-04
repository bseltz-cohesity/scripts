# Update Windows File-Based Protection to Protect All Local Drives using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script updates physical file-based Windows protection to protect all local drives, if only the C drive is protected (the default).

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/updateWindowsAllDrives/updateWindowsAllDrives.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x updateWindowsAllDrives.py
# end download commands
```

## Components

* updateWindowsAllDrives.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./updateWindowsAllDrives.py -v mycluster \
                            -u myuser \
                            -d mydomain.net
```

## Authentication Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -m, --mfacode: (optional) MFA code for authentication
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: (optional) name of the job to update (repeat for multiple)
* -l, --joblist: (optional) text file of job names to update (one per line)
* -c, --commit: (optional) commit changes (if omitted, only show what it would do )
* -s, --skiphostwithexcludes: (optional) do not update host if there are excludes present
