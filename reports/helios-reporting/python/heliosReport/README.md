# Generate Helios Reports using  using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This Python script creates helios reports and outputs to HTML, CSV and TSV files.

## Components

* heliosReport.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/helios-reporting/python/heliosReport/heliosReport.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x heliosReport.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./heliosReport.py  -u myusername@mydomain.net
```

## Parameters

* -v, --vip: (optional) defaults to helios.cohesity.com
* -u, --username: (optional) defaults to helios
* -s, --startdate: (optional) specify start of date range
* -e, --enddate: (optional) specify end of date range
* -t, --thismonth: (optional) set date range to this month
* -l, --lastmonth: (optional) set date range to last month
* -y, --days: (optional) limit report to last X days (default is 7)
* -x, --dayrange: (optional) limit day range per API query (default is 180)
* -m, --maxrecords: (optional) max number of records to retrieve per API query (default is 20000)
* -hr, --hours: (optional) limit report to last X hours
* -n, --units: (optional) MiB or GiB (default is MiB)
* -r, --reportname: (optional) name of helios report (default is 'Protection Runs')
* -c, --clustername: (optional) limit to one or more cluster names (repeat for multiple)
* -z, --timezone: (optional) default is 'America/New_York'
* -sr, --showrecord: (optional) show format of one record and exit
* -f, --filter: (optional) one or more filters, e.g. -f 'numSnapshots==0' -f 'protectionStatus==protected'
* -fl, --filterlist: (optional) text file of items to search for (e.g. server names)
* -fp, --filterproperty: (optional) property to search for items (e.g. objectName)
* -o, --outputpath: (optional) path to write output files (default is '.')
* -of, --outputfile: (optional) filename (minus extension) to name output files (default is automatic)

## Filters

You can filter on any valid attribute name and value. Comparisons can be one of ==, !=, >=, <=, > or <

To see what the attribute names are, use the -sr, --showrecord option. This will display one record and exit, so that you can see what the attribute names and value types are

You can include multiple filters like: `-f 'groupName==My Protection Group' -f 'logicalSize>=10000000000' -f 'objectName==server1.mydomain.net'`

## Using filter list

You can provide a text file (of server names for example) to search for by using --filterlist and --filterproperty. Create a text file of objects you want to search for (for example, myservers.txt) and then you can do, for example:

```bash
./heliosReport.py -u myusername@mydomain.net `
                  -r 'Protected Objects' `
                  -fp objectName `
                  -fl ./myservers.txt
```

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

If you enter the wrong password, you can re-enter the password like so:

```python
> from pyhesity import *
> apiauth(updatepw=True)
Enter your password: *********************
```
