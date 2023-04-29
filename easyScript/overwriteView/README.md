# Overwrite a View using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script overwrites a view with the contents of another view.

Warning: this script will overwrite data on the target view. Make sure you kknow what you are doing!

## Download the Script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/easyScript/overwriteView/overwriteView.zip
# end download commands
```

## Uploading the script to EasyScript

* In EasyScript, click "Upload a Script"
* Enter a descriptive name for the script
* Select Python 2.7 or 3.7 (both work for this script)
* enter a description (optional)
* enter the arguments (see below)
* browse and upload the zip file

## Arguments

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: password or API key
* -c, --clustername: (optional) helios/mcm cluster to connect to (will loop through all clusters if connected to helios)
* -s, --sourceview: name of source view
* -t, --targetview: name of target view to overwrite

## Example

To connect directly to a cluster:

```bash
-v mycluster -u myuser -d mydomain.net -s view1 -t view2 -pwd Sw0rdFish!
```

To connect via Helios:

```bash
-c mycluster -u myuser@mydomain.net -s view1 -t view2 -pwd 3abd0bc2-4fc4-57b0-412b-3c01d54d2727
```

## Getting an API Key for Helios

Helios uses an API key for authentication. To acquire an API key:

* log onto Helios
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again).
