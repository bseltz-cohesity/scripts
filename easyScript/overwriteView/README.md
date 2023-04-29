# Overwrite a View using EasyScript

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script overwrites a view with the contents of another view.

Warning: this script will overwrite data on the target view. Make sure you kknow what you are doing!

## Download the Script

You can download the zip file here: <https://github.com/bseltz-cohesity/scripts/raw/master/easyScript/overwriteView/overwriteView.zip>

## Uploading the script to EasyScript

1. In EasyScript, click "Upload a Script"
2. Enter a descriptive name for the script
3. Select Python 2.7 or 3.7 (both work for this script)
4. enter a description (optional)
5. enter the arguments (see below)
6. browse and upload the zip file
7. Optionally configure a schedule

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

To connect directly to a cluster using a username and password:

```bash
-v mycluster -u myuser -d local -s view1 -t view2 -pwd Sw0rdFish!
# for an AD account use -d mydomain.net (FQDN)
```

To connect directly to a cluster using an API Key

```bash
-v mycluster -s view1 -t view2 -i -pwd 3abd0bc2-4fc4-57b0-412b-3c01d54d2727
```

To connect via Helios using an API Key:

```bash
-c mycluster -s view1 -t view2 -pwd 3abd0bc2-4fc4-57b0-412b-3c01d54d2727
```

## Getting an API Key for Helios

Helios uses an API key for authentication. To acquire an API key:

1. log onto Helios
2. click Settings -> access management -> API Keys
3. click Add API Key
4. enter a name for your key
5. click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again).
