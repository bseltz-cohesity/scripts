# Restore Files from Cohesity backups using Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script restores files from a Cohesity physical server or NAS backup.

## Components

* [restoreFiles.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreFiles/restoreFiles.py): the main python script
* [pyhesity.py](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity/pyhesity.py): the Cohesity REST API helper module

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/restoreFiles/restoreFiles.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/pyhesity.py
chmod +x restoreFiles.py
# end download commands
```

Place both files in a folder together and run the main script like so:

```bash
# example
./restoreFiles.py -v mycluster \
                  -u myusername \
                  -d mydomain .net \
                  -s server1.mydomain.net \
                  -t server2.mydomain.net \
                  -n /home/myusername/file1 \
                  -n /home/myusername/file2 \
                  -p /tmp/restoretest/ \
                  -f '2020-04-18 18:00:00' \
                  -w
# end example
```

```text
Connected!
Restoring Files...
Restore finished with status kSuccess
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

## Other Parameters

* -s, --sourceserver: name of source server (repeat for multiple)
* -t, --targetserver: (optional) name of target server (defaults to source server [0])
* -rs, --registeredsource: (optional) name of registered source (e.g. name of registered netapp, isilon)
* -rt, --registeredtarget: (optional) name of registered target (e.g. name of registered netapp, isilon)
* -n, --filename: (optional) path of file to recover (repeat parameter for multiple files)
* -f, --filelist: (optional) text file containing multiple files to restore
* -p, --restorepath: (optional) path to restore files on target server (defaults to original location)
* -r, --runid: (optional) select backup version with this job run ID
* -b, --start: (optional) oldest backup date to restore files from (e.g. '2020-04-18 18:00:00')
* -e, --end: (optional) newest backup date to restore files from (e.g. '2020-04-20 18:00:00')
* -l, --latest: (optional) use latest backup date to restore files from
* -o, --newonly: (optional) only restore if there is a new point in time to restore
* -x, --noindex: (optional) do not use search index to find files
* -w, --wait: (optional) wait for completion and report status
* -k, --taskname: (optional) set name of recovery task
* -z, --sleeptimeseconds: (optional) sleep X seconds between status queries (default is 30)

## Backup Versions

By default, the script will search for each file and restore it from the newest version available for that file. You can narrow the date range that will be searched by using the --start and --end parameters.

Using the --runid or --latest parameters will cause the script to try to restore all the requested files at once (in one recovery task), from one backup version.

## File Names and Paths

File names must be specified as absolute paths like:

* Linux: /home/myusername/file1
* Windows: c:\Users\MyUserName\Documents\File1 or C/Users/MyUserName/Documents/File1

## Restoring a Folder or All Children of a Folder

You can restore an entire folder, like so:

```bash
# example
./restoreFiles.py -v mycluster \
                  -u myusername \
                  -d mydomain .net \
                  -s server1.mydomain.net \
                  -n /folder1 \
                  -p /folder2 \
                  -w
# end example
```

The above will result in the folder being restored to /folder2/folder1

If, instead you wish to restore the children of /folder1 to be restored directly into /folder2, then specify `-n /folder1/*`:

```bash
# example
./restoreFiles.py -v mycluster \
                  -u myusername \
                  -d mydomain .net \
                  -s server1.mydomain.net \
                  -n /folder1/* \
                  -p /folder2 \
                  -w
# end example
```

This will result in the children of /folder1 to be restored directly into /folder2

Note: the `/*` construct will only work for file-based backups (not block/volume based) and could be problematic if there are many immediate children of /folder1 (more than perhaps a few hundred), since each child will be restored individually, increasing restore time and increasing the restore parameter payload (too large a payload will fail).

Also note that `/*` does not function as a wildcard search operator. It means "all children'. It does not support searches like /folder1/*.doc, etc.

If `/*` does not work, then revert to the previous example, and after the restore, on the host you can `mv /folder2/folder1/* /folder2 && rmdir /folder2/folder1`

## The Python Helper Module - pyhesity.py

Please find more info on the pyhesity module here: <https://github.com/cohesity/community-automation-samples/tree/main/python>
