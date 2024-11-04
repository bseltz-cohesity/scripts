# Generate Estimated Storage Per VM Report using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script creates a report of data read/written per VM. Note that this report performs some estimations so is not expected to be completely accurate.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/python/dataReadPerVMReport/dataReadPerVMReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x dataReadPerVMReport.py
# end download commands
```

## Components

* dataReadPerVMReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./dataReadPerVMReport.py -v mycluster -u myusername -d mydomain.net
# end example
```

## Parameters

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to (repeat for multiple)
* -m, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -of: --outfolder: (optional) where to write report html (default is current directory)
* -x, --units: (optional) KiB, MiB, GiB, or TiB] (default is GiB)
* -n, --pagesize: (optional) number of runs per API query (default is 500)
* -s, --skipdeleted: (optional) skip deleted protection groups
* -y, --days: (optional) look back X days (defaul is 30)
