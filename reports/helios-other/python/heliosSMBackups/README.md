# List Helios Self-Managed Backups using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script lists Helios Self-Managed backups and outputs to a CSV file.

## Components

* heliosSMBackups.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/helios-other/python/heliosSMBackups/heliosSMBackups.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x heliosSMBackups.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./heliosSMBackups.py -v myhelios.mydomain.net -u myuser
```

## Parameters

* -v, --vip: (optional) DNS or IP of the Helios endpoint (defaults to helios.cohesity.com)
* -u, --username: (optional) username to store helios API key (defaults to helios)
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -n, --numruns: (optional) number of backups to retrieve (default is 100)
* -o, --outfolder: (optional) folder to write output file (default is '.')
* -c, --exportconfig: (optional) output s3 backup config to a text file
* -k, --hidesecretkey: (optional) hide secret key from config file export

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

Please see here for more information: <https://github.com/cohesity/community-automation-samples/tree/main/python#cohesity-rest-api-python-examples>

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
