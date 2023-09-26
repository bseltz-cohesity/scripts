# Gather Helios Cluster License Usage Stats Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script gathers license usage stats and outputs to an HTML report

## Components

* heliosLicenseReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/reports/heliosV1/python/heliosLicenseReport/heliosLicenseReport.py
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/pyhesity.py
chmod +x heliosLicenseReport.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./heliosLicenseReport.py
```

## Parameters

* -u, --username: (optional) username to store helios API key (defaults to helios)
* -d, --domain: (optional) domain of username to store helios API key (default is local)
* -pwd, --password: (optional) uses stored password by default
* -of, --outfolder: (optional) defaults to '.'

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

Please see here for more information: <https://github.com/bseltz-cohesity/scripts/tree/master/python#cohesity-rest-api-python-examples>

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click the gear icon -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
