# Monitor Helios Self-Managed Startup using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script monitors the startup of Helios self-managed. I will attempt to authenticate to Helios self-managed until it is successful.

## Components

* [heliosMonitor.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/heliosMonitor/heliosMonitor.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/heliosMonitor/heliosMonitor.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x heliosMonitor.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./heliosMonitor.py -v myhelios.mydomain.net \
                   -u admin
```

## Parameters

* -v, --vip: DNS or IP of Helios self-managed
* -u, --username: (optional) username to store helios API key (defaults to helios)
* -pwd, --password: (optional) API key to access helios
* -np, --noprompt: (optional) do not prompt for API key
* -s, --sleeptime: (optional) seconds to sleep betwen status checks (default is 30)
* -t, --timeout L (optional) seconrds before timing out (default is 3600)

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

Please see here for more information: <https://github.com/cohesity/community-automation-samples/tree/main/python#cohesity-rest-api-python-examples>

## Authenticating to Helios Self Managed

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click Settings -> Access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
