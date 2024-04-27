# Download and Extract Recovered Zip File using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This script downloads and extracts a recovered zip file from a file-level recovery from archive.

**Warning**: zip extraction will `overwrite` existing files without asking. Make sure you know what you are doing!

## Download the scripts

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/downloadZipFile/downloadZipFile.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x downloadZipFile.py
# end download commands
```

## Components

* [downloadZipFile.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/downloadZipFile/downloadZipFile.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

## Example

Go ahead and use the Cohesity UI to perform your file-level recovery from archive and choose the download option. When the recovery task is complete, a download file will be available (via a button in the recovery task). Take note of the recovery task name (e.g. Download_Files_Nov_25_2022_8_53_AM).

Then you can run the script on the server you wish to recover the files to, like so:

To download the zip and extract the files to ./recover :

```bash
./downloadZipFile.py -v mycluster \
                     -u myusername \
                     -d mydomain.net \
                     -n 'Download_Files_Nov_25_2022_8_53_AM' \
                     -r ./recover
```

Or to download the zip and extract to the files to their original locations :

```bash
./downloadZipFile.py -v mycluster \
                     -u myusername \
                     -d mydomain.net \
                     -n 'Download_Files_Nov_25_2022_8_53_AM' \
                     -r /
```

Note that the zip file contains the full path structure of the recovered files (e.g. /home/myusername/myfiles) so recovering to `/` puts the files back to their original locations.

## Authentication Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to (default is helios.cohesity.com)
* -u, --username: username to authenticate to Cohesity cluster (default is helios)
* -d, --domain: (optional) domain of username (defaults to local)
* -i, --useApiKey: (optional) use API key for authentication
* -pwd, --password: (optional) password or API key (will prompt or use stored password if omitted)

## Other Parameters

* -n, --recoveryname: name of recovery task (e.g. Download_Files_Nov_25_2022_8_53_AM)
* -t, --tempdir: (optional) path to download zip file (default is ./tmp)
* -r, --recoverydir: use / to restore to original location
