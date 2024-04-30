# Overwrite a View using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script overwrites a view with the contents of another view.

Warning: this script will overwrite data on the target view. Make sure you kknow what you are doing!

## Download the Script

You can download the zip file here: <https://github.com/cohesity/community-automation-samples/raw/main/easyScript/overwriteView/overwriteView.zip>

## Uploading the script to EasyScript

1. In EasyScript, click "Upload a Script"
2. Enter a descriptive name for the script
3. Select Python 2.7 or 3.7 (both work for this script)
4. enter a description (optional)
5. enter the arguments (see below)
6. browse and upload the zip file
7. Optionally configure a schedule

## Authentication Arguments

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: password or API key
* -c, --clustername: (optional) helios/mcm cluster to connect to (will loop through all clusters if connected to helios)

## Mandatory Arguments

* -s, --sourceview: name of source view
* -t, --targetview: name of target view to overwrite

## Optional Job Arguments

* -j, --waitforjob: (optional) name of protection group to wait for (will wait for archival task)
* -l, --lookbackhours: (optional) look back X hours for protection group run (default is 23)
* -z, --sleeptime: (optional) seconds to sleep between run queries (default is 60)

## Optional Mail Arguments

* -ms, --mailserver: (optional) SMTP server to send mail through
* -mp, --mailport: (optional) SMTP server port (default is 25)
* -to, --sendto: (optional) email address to send report to (repeat for multiple)
* -fr, --sendfrom: (optional) email address to send report from

## Examples

To connect directly to a cluster using a username and password:

```bash
# example
-v mycluster -u myuser -d local -s view1 -t view2 -pwd Sw0rdFish! -j 'my view backup'
# for an AD account use -d mydomain.net (FQDN)
# end example
```

To connect directly to a cluster using an API Key

```bash
# example
-v mycluster -s view1 -t view2 -i -pwd 3abd0bc2-4fc4-57b0-412b-3c01d54d2727 -j 'my view backup'
# end example
```

To connect via Helios using an API Key:

```bash
# example
-c mycluster -s view1 -t view2 -pwd 3abd0bc2-4fc4-57b0-412b-3c01d54d2727 -j 'my view backup'
# end example
```

To send completion status to email recipients:

```bash
# example
-v mycluster -u myuser -d local -s view1 -t view2 -pwd Sw0rdFish! -j 'my view backup' -ms mail.mydomain.net -to someone@mydomain.net -to someoneelse@mydomain.net -fr myscript@mydomain.net
# end example
```

## Getting an API Key for Helios

Helios uses an API key for authentication. To acquire an API key:

1. log onto Helios
2. click Settings -> access management -> API Keys
3. click Add API Key
4. enter a name for your key
5. click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again).
