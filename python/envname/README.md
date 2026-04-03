# Identify Environment Variables for Use with Pyhesity

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script lets you know what environment variables you can use for passwords or API keys for use with pyhesity-based scripts. After the script reports the environment variables, you can use your operating systems commands for exporting the variable to store your secret. pyhesity-based scripts will use your secret (requires pyhesity version 2026.04.03 or later).

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/envname/envname.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x envname.py
# end download commands
```

## Components

* [envname.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/envname/envname.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To identify the environment variables you can use for a cluster password:

```bash
./envname.py -v mycluster \
             -u myusername \
             -d mydomain.net
```

or a cluster API key:

```bash
./envname.py -v mycluster \
             -u myusername \
             -d mydomain.net \
             -i
```

or Helios:

```bash
./envname.py -u myusername
```

After the script reports the environment variables you can use, you can use your operating systems commands for exporting the variable to store your secret. pyhesity-based scripts will use your secret (requires pyhesity version 2026.04.03 or later).

## Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
