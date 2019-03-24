# Clone a Cohesity View Directory using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script clones a directory within a view.

## Components

* cloneDirectory.py: the main python script
* pyhesity.py: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```bash
bash:~/python$ ./cloneDirectory.py -s mycluster -u admin -d mydomain -sp /View1/folder1 -dp /View1 -nd folder2
Connected!
Cloning directory /View1/folder1 to /View1/folder2...
```

## The Python Helper Module - pyhesity.py

The helper module provides functions to simplify operations such as authentication, api calls, storing encrypted passwords, and converting date formats. The module requires the requests python module.

### Installing the Prerequisites

```bash
sudo yum install python-requests
```

or

```bash
sudo easy_install requests
```

### Downloading the Files

Go to the folder where you want to download the files, then run the following commands:

```bash
curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/cloneDirectory/cloneDirectory.sh

curl -O https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/python/cloneDirectory/pyhesity.py

chmod +x cloneDirectory.sh
```