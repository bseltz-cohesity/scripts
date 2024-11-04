# Enable of Disable Support Channel using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script enables, disables or extends support channel.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/supportChannel/supportChannel.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x supportChannel.py
# end download commands
```

## Components

* [supportChannel.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/supportChannel/supportChannel.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To see the current state of support channel:

```bash
# example
./supportChannel.py -v mycluster -u myusername -d mydomain.net
# end example
```

To enable or extend support channel for 1 day:

```bash
# example
./supportChannel.py -v mycluster -u myusername -d mydomain.net -e
# end example
```

To enable or extend support channel for 5 day:

```bash
# example
./supportChannel.py -v mycluster -u myusername -d mydomain.net -e -y 5
# end example
```

To disable support channel:

```bash
# example
./supportChannel.py -v mycluster -u myusername -d mydomain.net -x
# end example
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -e, --enable: (optional) enable support channel
* -y, --days: (optional) number of days to enable or extend support channel (default is 1)
* -x, --disable: (optional) disable support channel
