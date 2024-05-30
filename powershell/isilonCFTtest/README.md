# Test Isilon Change File Tracking Performance in PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script tests Isilon Change File Tracking performance.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'isilonCFTtest'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/isilon-api/isilon-api.ps1").content | Out-File "isilon-api.ps1"; (Get-Content "isilon-api.ps1") | Set-Content "isilon-api.ps1"
# End Download Commands
```

## Components

* [isilonCFTtest.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/isilonCFTtest/isilonCFTtest.ps1): the main powershell script
* [isilon-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/isilon-api/isilon-api.ps1): the Isilon REST API helper module

## How the test works

The performance test is performed in three phases:

* An initial snapshot is created (or you can choose an existing snapshot that is hours or days old)
* Wait some length of time (usually 24 hours) to allow changed files to accumulate on the file system, then create a second snapshot, and create a change file tracking job between the two snapshots
* Wait for the change file tracking job to complete, and report job duration

## List existing snapshots

If you want to use existing snapshots for the first snapshot, second snapshot or both, you can list the existing snapshots:

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -path /ifs/share1 `
                    -listSnapshots
```

## Run the test

If there are no existing snapshots, you can simply run the test:

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -path /ifs/share1
```

Or if you wish to use an existing snapshot for the first snapshot (you can specify the snapshot name or ID):

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -path /ifs/share1 `
                    -firstSnapshot 534
```

Or you can use existing snapshots for both first and second snapshots:

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -path /ifs/share1 `
                    -firstSnapshot 534 `
                    -secondSnapshot 544
```

If the first snapshot does not exist, it will be created, and the script will exit. You should wait 24 hours (or at least a few hours) for changes to the file system before re-running the script (with the same parameters) to proceed to the next step.

If the first snapshot already exists, the second snapshot will be created (or existing snapshot used), and the CFT test job will be initiated.

The script will then wait for CFT job completion and report the job duration (the script will poll the isilon every 15 seconds until completion), or you can press CTRL-C to exit the script, and re-run the script later (with the same parameters) to check the status.

## Delete the snapshots when finished

Re-run the script (with the same parameters as before) and append the `-deleteSnapshots` switch if you want to delete the snapshots that were used in the test, like:

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -path /ifs/share1 `
                    -firstSnapshot 534 `
                    -secondSnapshot 544 `
                    -deleteSnapshots
```

Or you can use -listSnapshots as above:

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -path /ifs/share1 `
                    -listSnapshots
```

And then delete a specific snapshot, specifying the snapshot name or ID:

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -deleteThisSnapshot 608
```

## Parameters

* -isilon: DNS name or IP of the Isilon to connect to
* -username: user name to connect to Isilon
* -password: (optional) will prompt if omitted
* -path: file system path to monitor (e.g. /ifs/share1) required when creating the first snapshot
* -listSnapshots: list available snapshots for the specified path
* -firstSnapshot: name or ID of existing snapshot to use (or name of new snapshot to create)
* -secondSnapshot: name or ID of existing snapshot to use (or name of new snapshot to create)
* -deleteSnapshots: delete specified first and second snapshots and exit
* -deleteThisSnapshot: delete one snapshot and exit
