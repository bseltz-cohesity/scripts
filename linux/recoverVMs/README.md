# Recover VMware VMs for Linux

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This is a binary tool that recovers one or more VMs.

## Download the tool

Run these commands from a terminal to download the script(s) into your current directory

```bash
# Begin download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/linux/recoverVMs/recoverVMs
chmod +x recoverVMs
# End download commands
```

## Example

```bash
./recoverVMs -v mycluster \
             -u myusername \
             -d mydomain.net \
             -vm myvm1 \
             -p
```

To list available recovery points:

```bash
./recoverVMs -v mycluster \
             -u myusername \
             -d mydomain.net \
             -vm myvm1 \
             -l
```

To specify a recovery point:

```bash
./recoverVMs -v mycluster \
             -u myusername \
             -d mydomain.net \
             -vm myvm1 \
             -r '2021-04-12 23:45:01'
```

To restore a VM to a new location:

```bash
./recoverVMs -v mycluster \
             -u myusername \
             -d mydomain.net \
             -vm myvm1 \
             -vc myVcenter.mydomain.net \
             -dc mydatacenter \
             -vh myHAcluster \
             -f someFolder \
             -n 'vm network' \
             -p
```

## Authentication Parameters

* -v, --vip: (optional) DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: (optional) username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key
* -np, --noprompt: (optional) do not prompt for password
* -mcm, --mcm: (optional) connect through MCM
* -c, --clustername: (optional) helios/mcm cluster to connect to (repeat for multiple)
* -mfa, --mfacode: (optional) MFA code for authentication

## Other Parameters

* -vm, --vmname: Name of VM to recover (repeat for multiple)
* -vl, --vmlist: text file of VM names to recover (one per line)
* -vc, --vcentername: (optional) name of vcenter to restore to
* -tn, --taskname: (optional) name of recovery task
* -dc, --datacentername: (optional) name of vsphere data center to restore to
* -vh, --vhost: (optional) name of vSphere cluster or host to restore to
* -s, --datastorename: (optional) name of datastore to restore to
* -f, --foldername: (optional) name of vSphere folder to restore to
* -n, --networkname: (optional) name of VM network to attach to
* -x, --detachnetwork: (optional) leave network disconnected
* -m, --preservemacaddress: (optional) keep same mac address
* -t, --recoverytype: (optional) InstantRecovery or CopyRecovery (default is InstantRecovery)
* -pre, --prefix: (optional) prefix to apply to VM name
* -p, --poweron: (optional) power on the VM
* -l, --listrecoverypoints: (optional) show available recovery points (for first VM only)
* -r, --recoverypoint: (optional) restore from a specific date, e.g. '2021-04-12 23:45:00' (default is latest backup)

## Specifying a Folder

You can specify a folder to restore to using any of the following formats:

* /vCenter.mydomain.net/Datacenters/DataCenter1/vm/MyFolder/MySubFolder
* vCenter.mydomain.net/Datacenters/DataCenter1/vm/MyFolder/MySubFolder
* /MyFolder/MySubFolder
* MyFolder/MySubFolder
