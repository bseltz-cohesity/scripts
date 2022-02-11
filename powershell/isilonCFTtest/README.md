# Test Isilon Change File Tracking Performance in PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script tests Isilon Change File Tracking performance.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'isilonCFTtest'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
# End Download Commands
```

## How the test works

The performance test is performed in three phases:

* An initial snapshot is created
* Wait some length of time (usually 24 hours) to allow changed files to accumulate on the file system, then create a second snapshot, and create a change file tracking job between the two snapshots
* Wait for the change file tracking job to complete, and report job duration

The script has -phase1 -phase2 and -phase3 parameters for each of these phases.

First, we run phase 1 to create the initial snapshot

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -path /ifs/share1 `
                    -phase1
```

Then after some time, allowing for changed files to accumulate, we run phase 2 to create the second snapshot and start the CFT job:

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -path /ifs/share1 `
                    -phase2
```

Then run phase 3 to check for job completion and report the job duration (this could take hours):

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -phase3
```

If the job is not yet completed, repeat phase 3 until the job is complete, and then record the duration

When finished, we can clean up the snapshots:

```powershell
./isilonCFTtest.ps1 -isilon myisilon `
                    -username myusername `
                    -cleanUp
```

## Parameters

* -isilon: DNS name or IP of the Isilon to connect to
* -username: user name to connect to Isilon
* -password: (optional) will prompt if omitted
* -path: file system path to monitor (e.g. /ifs/share1) required for phase 1 & 2
* -phase1: perform phase 1
* -phase2: perform phase 2
* -phase3: perform phase 3
* -cleanUp: delete old snapshots and exit
