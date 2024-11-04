# Test Isilon Change File Tracking Performance in Python

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This python script tests Isilon Change File Tracking performance.

## Download the script

You can download the scripts using the following commands:

```bash
# download commands
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/isilonCFTtest/isilonCFTtest.py
curl -O https://raw.githubusercontent.com/cohesity/community-automation-samples/main/python/isilon_api/isilon_api.py
chmod +x isilonCFTtest.py
# end download commands
```

## How the test works

The performance test is performed in three phases:

* An initial snapshot is created (or you can choose an existing snapshot)
* Wait some length of time (usually 24 hours) to allow changed files to accumulate on the file system, then create a second snapshot, and create a change file tracking job between the two snapshots
* Wait for the change file tracking job to complete, and report job duration

## List existing snapshots

If you want to use existing snapshots for the first snapshot, second snapshot, or both, you can list the existing snapshots:

```bash
./isilonCFTtest.py -i myisilon \
                   -u myusername \
                   -p /ifs/share1 \
                   -l
```

## Run the test

If there are no existing snapshots, you can simply run the test and the first snapshot will be created:

```bash
./isilonCFTtest.py -i myisilon \
                   -u myusername \
                   -p /ifs/share1
```

Or if you wish to use an existing snapshot for the first snapshot, you can specify the snapshot name or ID:

```bash
./isilonCFTtest.py -i myisilon \
                   -u myusername \
                   -p /ifs/share1 \
                   -f 536
```

Or you can use existing snapshots for both first and second snapshots:

```bash
./isilonCFTtest.py -i myisilon \
                   -u myusername \
                   -p /ifs/share1 \
                   -f 536 \
                   -s 544
```

If the first snapshot does not exist, it will be created and the script will exit. You should wait 24 hours  for changes to the file system before re-running the script (with the same parameters) to proceed to the next step.

If the first snapshot already exists, the second snapshot will be created (or existing snapshot used), and the CFT test job will be initiated.

The script will then wait for CFT job completion and report the job duration (the script will poll the isilon every 15 seconds until completion), or you can press CTRL-C to exit the script, and re-run the script later (with the same parameters) to check the status.

## Delete the snapshots when finished

Re-run the script (with the same parameters as before) and append the `--deletesnapshots` (`-c`) switch if you want to delete the snapshots that were used in the test, like:

```bash
./isilonCFTtest.py -i myisilon \
                   -u myusername \
                   -p /ifs/share1 \
                   -f 536 \
                   -s 544 \
                   -c
```

Or you can use -listSnapshots as above:

```bash
./isilonCFTtest.py -i myisilon \
                   -u myusername \
                   -p /ifs/share1 \
                   -l
```

And then delete a specific snapshot, specifying the snapshot name or ID:

```bash
./isilonCFTtest.py -i myisilon \
                   -u myusername \
                   -p /ifs/share1 \
                   -d 544
```

## Parameters

* -i, --isilon: DNS name or IP of the Isilon to connect to
* -u, --username: user name to connect to Isilon
* -pwd, --password: (optional) will prompt if omitted
* -p, --path: (optional) file system path (e.g. /ifs/share1) required when creating the first snapshot
* -l, --listsnapshots: (optional) list available snapshots for the specified path
* -f, --firstsnapshot: (optional) name or ID of existing snapshot to use (or name of new snapshot to create)
* -s, --secondsnapshot: (optional) name or ID of existing snapshot to use (or name of new snapshot to create)
* -c, --deletesnapshots: (optional) delete specified first and second snapshots and exit
* -d, --deletethissnapshot: (optional) delete one snapshot and exit
