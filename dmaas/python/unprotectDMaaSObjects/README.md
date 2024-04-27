# Unprotect DMaaS Objects Using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script can perform a final backup and unprotect protected objects in DMaaS.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/dmaas/python/unprotectDMaaSObjects/unprotectDMaaSObjects.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x unprotectDMaaSObjects.py
# end download commands
```

## Components

* [unprotectDMaaSObjects.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/dmaas/python/unprotectDMaaSObjects/unprotectDMaaSObjects.py): the main powershell script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To run a final backup of some objects:

```bash
./unprotectDMaaSObjects.py -u myuser \
                           -n myvm1 \
                           -n myvm2 \
                           -n myvm3 \
                           -f
```

To run a final backup using an alternate policy:

```bash
./unprotectDMaaSObjects.py -u myuser \
                           -n myvm1 \
                           -n myvm2 \
                           -n myvm3 \
                           -p mypolicy
                           -f
```

To unprotect the objects after the final backup:

```bash
./unprotectDMaaSObjects.py -u myuser \
                           -n myvm1 \
                           -n myvm2 \
                           -n myvm3 \
                           -x
```

## Parameters

* -u, --username: (optional) username to authenticate to DMaaS (used for password storage only)
* -pwd, --password: (optional) API key for authentication
* -np, --noprompt: (optional) do not prompt for API key, exit if not authenticated
* -n, --objectname: (optional) protected object name to backup/unprotect  (repeat for multiple)
* -l, --objectlist: (optional) text file of protected object names to backup/unprotect (one per line)
* -p, --policyname: (optional) name of protection policy to use
* -f, --finalbackup: (optional)
* -x, --unprotect: (optional)
* -z, --nobackuprequired: (optional)

## Authenticating to DMaaS

DMaaS uses an API key for authentication. To acquire an API key:

* log onto DMaaS
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a DMaaS compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
