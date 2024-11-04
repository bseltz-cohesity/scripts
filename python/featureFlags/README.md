# Get Set Export and Import Feature Flags using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script gets, sets, exports and imports feature flags.

## Components

* [featureFlags.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/featureFlags/featureFlags.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity python helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/featureFlags/featureFlags.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x featureFlags.py
# end download commands
```

Place both files in a folder together and run the main script like so:

### Listing Feature Flags

To list existing feature flags (ouputs to a CSV file):

```bash
# example
./featureFlags.py -v mycluster \
                  -u myuser \
                  -d mydomain.net
# end example
```

### Setting a Feature Flag

Non-UI feature:

```bash
# example
./featureFlags.py -v mycluster \
                  -u myuser \
                  -d mydomain.net \ 
                  -n magneto_master_enable_read_replica \
                  -r 'read replica'
# end example
```

UI feature:

```bash
# example
./featureFlags.py -v mycluster \
                  -u myuser \
                  -d mydomain.net \ 
                  -n some_feature \
                  -r 'cool feature' \
                  -ui
# end example
```

### Clearing a Feature Flag

Non-UI feature:

```bash
# example
./featureFlags.py -v mycluster \
                  -u myuser \
                  -d mydomain.net \ 
                  -n some_feature \
                  -x
# end example
```

UI Feature:

```bash
# example
./featureFlags.py -v mycluster \
                  -u myuser \
                  -d mydomain.net \ 
                  -n some_feature \
                  -ui \
                  -x
# end example
```

### Importing a List of Feature Flags

To import feature flags from a CSV file:

```bash
# example
./featureFlags.py -v mycluster \
                  -u myuser \
                  -d mydomain.net \ 
                  -i myfile.csv
# end example
```

## Cohesity Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -k, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -n, --flagname: (optional) Name of feature flag to set
* -r, --reason: (optional) reason for setting the flag
* -ui, --isuifeature: (optional) specify that feature flag is a UI feature (false if omitted)
* -x, --clear: (optional) remove the feeature flag
* -i, --importfile: (optional) name of file to import

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```

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
