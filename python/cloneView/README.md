# Clone a Cohesity View using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script clones a view.

## Downloading the Files

Go to the folder where you want to download the files, then run the following commands:

```bash
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/cloneView/cloneView.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x cloneView.py
```

## Components

* [cloneView.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/cloneView/cloneView.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
./cloneView.py -s mycluster -u admin [ -d domain ] -v myview -n newview [ -f '2020-04-18 18:00:00' ] [ -w ]
Connected!
Cloning View myview as newview...
```

## Parameters

* -s, --server: DNS or IP of the Cohesity cluster to connect to
* -u, --username: username to authenticate to Cohesity cluster
* -d, --domain: (optional) domain of username, defaults to local
* -v, --view: name of source view to be cloned
* -n, --newname: name of clone view to create
* -f, --filedate: (optional) select backup version at or after specified date (defaults to latest backup)
* -b, --before: (optional) select last backup version before file date (default is to use next backup after file date)
* -w, --wait: (optional) wait for completion and report exit status

## Dates

Use the `-f` parameter to specify the date from which to clone the view. The date may be entered like: `'2020-04-20 17:05:00'` or `'2020-04-20'` (which is interpreted as `'2020-04-20 00:00:00'`).

The oldest snapshot that is equal to or newer than the specified date will be used. For example, if the view is backed up every night at 9PM and you enter `-f '2020-04-20 12:00:00'`, the backup from April 20th at 9PM would be selected. Use the `-b` parameter to reverse this behavior and use the newest snapshot that is older than the specified date.

If the `-f` parameter is omitted, then the latest backup is used by default.

## The Python Helper Module - pyhesity.py

Please find more info on the pyhesity module here: <https://github.com/cohesity/community-automation-samples/tree/main/python>
