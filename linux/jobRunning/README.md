# See if a Protection Job is Running for Linux

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a binary version of jobRunning for Linux. It determines if a protection job is running or not. If it is running, it will exit with exit code 1, otherwise it will exit with exit code 0.

Note: the binary was tested successfully on CentOS 7, Ubuntu 18.04.4 and Fedora 35.

## Download the tool

Run these commands from bash to download the tool into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/linux/jobRunning/jobRunning
chmod +x jobRunning
# End download commands
```

## Example

```bash
./jobRunning -v mycluster -u myusername -d mydomain.net -j myjob
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -t, --tenant: (optional) multi-tenancy tenant name
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to
* -m, --mfacode: (optional) MFA code for authentication
* -e --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -j, --jobname: name of job to display (repeat parameter for multiple jobs)
