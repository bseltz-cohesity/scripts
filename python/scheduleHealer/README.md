# Schedule Healer Run using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script schedules an Apollo healer run (which will expidite garbage collection).

## Download the script

Run these commands to download the scripts into your current directory

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/scheduleHealer/scheduleHealer.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x scheduleHealer.py
```

## Components

* [scheduleHealer.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/scheduleHealer/scheduleHealer.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
#example
./scheduleHealer.py -v mycluster \
                    -u myusername \
                    -d mydomain.net
#end example
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -m, --mfacode: (optional) MFA code for authentication
* -e, --emailmfscode: (optional) send MFA code via email
