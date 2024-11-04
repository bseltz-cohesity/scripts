# Measure Change Rate between Pure FlashArray Snapshots Using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script measures the change rate between two snapshots on a Pure FlashArray.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'pureSnapDiff'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'pure-api'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/pureSnapDiff/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## How the test works

The change rate measurement is performed in two phases:

* An initial snapshot is created (or you can choose an existing snapshot that is hours or days old)
* Wait some length of time (usually 24 hours) to allow change rate to accumulate, then create a second snapshot

## List existing snapshots

If you want to use existing snapshots for the first snapshot, second snapshot or both, you can list the existing snapshots:

```powershell
./pureSnapDiff.ps1 -pure mypure `
                   -username myusername `
                   -volumeName myvolume `
                   -listSnapshots
```

## Create a Snapshot

```powershell
./pureSnapDiff.ps1 -pure mypure `
                   -username myusername `
                   -volumeName myvolume `
                   -createSnapshot
```

## Delete a snapshot

```powershell
./pureSnapDiff.ps1 -pure mypure `
                   -username myusername `
                   -volumeName myvolume `
                   -deleteSnapshot myvolume.2
```

## Run the diff test

If there is an existing snapshot that is hours or days old, you can run a diff test. If a second snapshot is not specified, a new one will be created:

```powershell
./pureSnapDiff.ps1 -pure mypure `
                   -username myusername `
                   -volumeName myvolume `
                   -firstSnapshot myvolume.1
                   -diffTest
```

Or you can specify an existing second snapahot:

```powershell
./pureSnapDiff.ps1 -pure mypure `
                   -username myusername `
                   -volumeName myvolume `
                   -firstSnapshot myvolume.1 `
                   -secondSnapshot myvolume.2 `
                   -diffTest
```

You can specify the block size (in KiB) to test with:

```powershell
./pureSnapDiff.ps1 -pure mypure `
                   -username myusername `
                   -volumeName myvolume `
                   -firstSnapshot myvolume.1 `
                   -secondSnapshot myvolume.2 `
                   -blockSize1 10240 `
                   -diffTest
```

Or you can compare two block sizes (in KiB):

```powershell
./pureSnapDiff.ps1 -pure mypure `
                   -username myusername `
                   -volumeName myvolume `
                   -firstSnapshot myvolume.1 `
                   -secondSnapshot myvolume.2 `
                   -blockSize1 10240 `
                   -blockSize2 1024 `
                   -diffTest
```

## Basic Parameters

* -pure: DNS name or IP of the pure to connect to
* -username: user name to connect to pure
* -password: (optional) will prompt if omitted
* -storePassword: (optional) store password for future use
* -volumeName: name of volume to test
* -version: (optional) pure API version (default is 1.19)

## Snapshot Selection Parameters

* -listSnapshots: (optional) list available snapshots for the specified volume and exit
* -firstSnapshot: (optional) name of existing snapshot to use for diff test
* -secondSnapshot: (optional) name of existing snapshot to use for diff test
* -createSnapshot: (optional) create a snapshot for the specified volume and exit
* -deleteSnapshot: (optional) delete specified snapshot and exit

## Diff Test Parameters

* -diffTest: (optional) perform diff test
* -blockSize1: (optional) in KiB - default is 10240 (10 MiB)
* -blockSize2: (optional) in KiB - default is None
* -unit: (optional) MiB or GiB (default is GiB)
* -lengthDivisor: (optional) 2, 4, 8, 16... (default is 1)
* -stopAfter: (optional) stop after X queries (e.g. -stopAfter 2)
