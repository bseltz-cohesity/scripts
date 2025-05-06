# Refresh a Protection Source

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a binary version of refreshSource, for Linux, that refreshes a protection source.

Note: the binary was tested successfully on CentOS 7, Ubuntu 18.04.4 and Fedora 35.

## Download the tool

Run these commands from bash to download the tool into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/linux/refreshSource/refreshSource
chmod +x refreshSource
# End download commands
```

## Example

```bash
./refreshSource -v mycluster \
                -u myuser \
                -d mydomain.net \
                -n myserver1.mydomain.net
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
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -n, --sourcename: name of protection source to refresh (repeat for multiple sources)
* -l, --sourcelist: text file of protection sources to refresh (one per line)
* -env, --environment: (optional) limit search for protection sources to specific type (e.g. kVMware)
* -s, --sleepseconds: (optional) sleep X seconds between status queries (default is 30)
