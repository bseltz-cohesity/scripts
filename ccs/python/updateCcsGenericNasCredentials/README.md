# Update CCS Generic NAS Credentials using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script updates the SMB credentials of registered Generic NAS (kGenericNas) protection sources in CCS.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/updateCcsGenericNasCredentials/updateCcsGenericNasCredentials.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x updateCcsGenericNasCredentials.py
# end download commands
```

## Components

* [updateCcsGenericNasCredentials.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/ccs/python/updateCcsGenericNasCredentials/updateCcsGenericNasCredentials.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

To see the list of Generic NAS sources:

```bash
./updateCcsGenericNasCredentials.py
```

To filter by region:

```bash
./updateCcsGenericNasCredentials.py -r us-east-2
```

To filter by mount mode:

```bash
./updateCcsGenericNasCredentials.py -m kCifs1
```

To filter by name:

```bash
./updateCcsGenericNasCredentials.py -sn '\\nas1\share1' -sn '\\nas1\share2'
```

To update credentials for specific sources:

```bash
./updateCcsGenericNasCredentials.py -sn '\\nas1\share1' -sn '\\nas1\share2' \
                                    -x \
                                    -su 'mydomain.net\myuser'
```

To update the password for all sources currently using a particular SMB user:

```bash
./updateCcsGenericNasCredentials.py -x -su 'mydomain.net\myuser'
```

## Basic Parameters

* -u, --username: (optional) username to authenticate to Ccs (used for password storage only)
* -pwd, --password: (optional) API key for authentication
* -np, --noprompt: (optional) do not prompt for API key, exit if not authenticated

## Filter Parameters

* -r, --region: (optional) filter by a single CCS region id (e.g. us-east-2)
* -sn, --sourcename: (optional) filter by registered source name (repeat for multiple)
* -sl, --sourcelist: (optional) text file of registered source names to filter by (one per line)
* -m, --mode: (optional) filter by mount mode (kNfs3, kNfs4_1 or kCifs1)

## Update Parameters

* -x, --update: (optional) perform credential update
* -su, --smbuser: (optional) SMB username for credential update (will be prompted if omitted)
* -sp, --smbpassword: (optional) SMB password for credential update (will be prompted if omitted)

## Notes

* The source list (and `genericnas-sources.csv`) includes the mount point, region, mode and current SMB user of each source.
* If no `-sn` or `-sl` is specified and `-su` is specified, the script operates on all sources that currently use that SMB user (so you can update a password across every source using the same account). With `-su` and no names, list mode shows only those sources.
* If `-x` is used with `-su` and no source names, the existing username is kept and only the password changes.
* If source names are specified, those sources are updated to the given `-su` regardless of their current user.
* Credentials apply only to SMB (kCifs1) sources. NFS sources are skipped during update.
* The existing mount point, mode, description and throttling settings are preserved during update.

## Authenticating to Ccs

Ccs uses an API key for authentication. To acquire an API key:

* log onto Ccs
* click Settings -> access management -> API Keys
* click Add API Key
* enter a name for your key
* click Save

Immediately copy the API key (you only have one chance to copy the key. Once you leave the screen, you can not access it again). When running a Ccs compatible script for the first time, you will be prompted for a password. Enter the API key as the password.
