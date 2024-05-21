# Delete Old Files in an S3 View using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script deletes files in an S3 view that are older than X time units.

**Warning**: This script deletes data! Make sure you test thoroughly before you run this script!!!

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/s3test/s3DeleteOldFiles/s3DeleteOldFiles.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x s3DeleteOldFiles.py
# end download commands
```

## Components

* [s3DeleteOldFiles.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/s3test/s3DeleteOldFiles/s3DeleteOldFiles.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
# example
./s3DeleteOldFiles.py -v ve2 -u admin -b s3bucket -o 31 -m days
# end example
```

## Parameters

* -v, --vip: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -b, --bucketname: name of the cohesity view
* -o, --olderthan: delete files older than X units
* -m, --timeunits: (optional) seconds, minutes, hours, days, weeks, months, years (default is days)
* -t, --tzoffset: (optional) your timezone hour adjustment from GMT time (default is 0)

## Dependencies

This script requires the following python modules (which are not part of the standard library):

* boto3 (AWS python module)
* requests (http requests module)

Please install these using pip, easy_install or yum
