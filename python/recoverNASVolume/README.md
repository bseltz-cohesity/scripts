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
                      -n netapp1.mydomain.net \
                      -t vol3
                      -m netapp1.mydomain.net \
                      -b '2020-04-18 18:00:00' \
                      -w
# end example
```

## Parameters

* `-v, --vip`: DNS or IP of the Cohesity cluster to connect to
* `-u, --username`: username to authenticate to Cohesity cluster
* `-d, --domain`: (optional) domain of username, defaults to local
* `-s, --sourcevolume`: name of volume or mount point to recover
* `-n, --sourcename`: (optional) name of registered source NAS
* `-t, --targetvolume`: (optional) name of target volume, mount point, or view name
* `-m, --targetname`: (optional) name of registered target NAS
* `-a, --asview`: (optional) recover as Cohesity view
* `-l, --showversions`: (optional) show available run IDs/dates and exit
* `-r, --runid`: (optional) select specific run ID
* `-b, --before`: (optional) select recovery date before this date (e.g. '2021-02-21 00:00:00')
* `-o, --overwrite`: (optional) overwrite existing volumes
* `-w, --wait`: (optional) wait for completion and report status

## Backup Versions

By default, the script will restore from the latest backup version. Using `--before` will tell the script to restore from the latest version before the specified date. Using `--runid` will use a specific backup run. Use `--showversions` to list the available run IDs.

## The Python Helper Module - pyhesity.py

Please find more info on the pyhesity module here: <https://github.com/cohesity/community-automation-samples/tree/main/python>
