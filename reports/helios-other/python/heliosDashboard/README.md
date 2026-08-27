# Build a Cluster Health Dashboard Across Helios Clusters using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script builds an HTML health/status dashboard for all clusters connected to Helios, including cluster health, version/upgrade status, node counts, capacity usage, open critical/warning alerts, and protection group status.

## Components

* heliosDashboard.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/helios-other/python/heliosDashboard/heliosDashboard.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x heliosDashboard.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
./heliosDashboard.py -u myusername
```

To customize the capacity unit, theme, alert window, and output file:

```bash
./heliosDashboard.py -u myusername -un GiB -th Light -a 14 -o dashboard.html -s
```

## Parameters

* -v, --vip: (optional) DNS or IP of the Helios endpoint (defaults to helios.cohesity.com)
* -u, --username: (required) username to store Helios API key
* -d, --domain: (optional) domain of username to store Helios API key (default is local)
* -p, --password: (optional) API key/password (will be prompted and stored if not provided)
* -un, --unit: (optional) GiB or TiB, unit used to display capacity values (defaults to TiB)
* -th, --theme: (optional) Light or Dark, dashboard color theme (defaults to Dark)
* -a, --alertdays: (optional) number of days to look back for active alert stats (defaults to 7)
* -o, --outfilename: (optional) name of the output HTML file (defaults to heliosDashboard-yyyy-MM-dd_HHmm.html)
* -s, --show: (optional) open the generated HTML file in the default browser when finished

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
