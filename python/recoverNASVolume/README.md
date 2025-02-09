# Recover a NAS Volume using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script recovers a NAS volume.

## Components

* [recoverNASVolume.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/recoverNASVolume/recoverNASVolume.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/recoverNASVolume/recoverNASVolume.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x recoverNASVolume.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./recoverNASVolume.py -v mycluster \
                      -u myusername \
                      -d mydomain.net \
                      -s vol2 \
                      -sn netapp1.mydomain.net \
                      -t vol3
                      -tn netapp1.mydomain.net
                      -w
# end example
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
* -e, --emailmfacode: (optional) send MFA code via email

## Other Parameters

* -s, --sourcevolume: name of volume or mount point to recover
* -sn, --sourcename: (optional) name of registered source NAS
* -tv, --targetvolume: (optional) name of target volume, mount point, or view name
* -tn, --targetname: (optional) name of registered target NAS
* -l, --showversions: (optional) show available run IDs/dates and exit
* -r, --runid: (optional) select specific run ID
* -o, --overwrite: (optional) overwrite existing volumes
* -w, --wait: (optional) wait for completion and report status

## Recover as View Parameters

* -av, --asview: (optional) recover as Cohesity view
* -vn, --viewname: (optional) name of view to create (source volume name is used by default)
* -smb, --smbview: (optional) set protocol access to SMB (NFSv3 by default)
* -fc, --fullcontrol: (optional) list of users to grant full control share permissions (repeat for multiple)
* -rw, --readwrite: (optional) list of users to grant read write share permissions (repeat for multiple)
* -ro, --readonly: (optional) list of users to grant read only share permissions (repeat for multiple)
* -mod, --modify: (optional) list of users to grant modify share permissions (repeat for multiple)
* -ip, --ips: (optional) cidrs to add, examples: 192.168.1.3/32, 192.168.2.0/24 (repeat for multiple)
* -il, --iplist: (optional) text file of cidrs to add (one per line)
* -rs, --rootsquash: (optional) enable root squash
* -as, --allsquash: (optional) enable all squash
* -ir, --ipsreadonly: (optional) readWrite if omitted

## Backup Versions

By default, the script will restore from the latest backup version. Using `--runid` will use a specific backup run. Use `--showversions` to list the available run IDs.

## The Python Helper Module - pyhesity.py

Please find more info on the pyhesity module here: <https://github.com/cohesity/community-automation-samples/tree/main/python>
