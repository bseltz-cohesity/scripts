# Update Secret Key for External Targets Across Helios Clusters using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script finds external targets that use the specified access key, and updates the secret access key.

## Components

* [heliosUpdateTargetSecretKey.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/heliosUpdateTargetSecretKey/heliosUpdateTargetSecretKey.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/heliosUpdateTargetSecretKey/heliosUpdateTargetSecretKey.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x heliosUpdateTargetSecretKey.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./heliosUpdateTargetSecretKey.py -a MYACCESSKEY
```

You will be prompted to enter the secret access key to apply to any external targets that use MYACCESSKEY.

## Parameters

* -u, --username: (optional) username to store helios API key (defaults to helios)
* -pwd, --password: (optional) API key to access helios
* -a, --accesskey: access key to search for
* -s, --secretkey: (optional) will be prompted by default

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

Please see here for more information: <https://github.com/cohesity/community-automation-samples/tree/main/python#cohesity-rest-api-python-examples>

## Authenticating to Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click Settings -> Access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Helios compatible script for the first time, you will be prompted for a password. Enter the API key as the password.

If you enter the wrong password, you can re-enter the password like so:

```python
> from pyhesity import *
> apiauth(updatepw=True)
Enter your password: *********************
```
