# Download CCS Agent using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script downloads a CCS Agent.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/downloadCCSAgent/downloadCCSAgent.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x downloadCCSAgent.py
# end download commands
```

## Components

* [downloadCCSAgent.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/downloadCCSAgent/downloadCCSAgent.py): the main powershell script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./downloadCCSAgent.py -p Windows
```

```bash
./downloadCCSAgent.py -p Linux -t RPM
```

## Parameters

* -u, --username: (optional) username to authenticate to Ccs (used for password storage only)
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -p, --platform: (optional) 'Windows' or 'Linux' (default is 'Windows')
* -t, --packageType: (optional) for Linux agent, 'RPM', 'DEB', 'Script' or 'SuseRPM' (default is 'RPM')

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
