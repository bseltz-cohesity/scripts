# Expunge Data Spillage with PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

This powershell script searches for a file, and displays the ProtectionJobs/Objects where the file is stored. Then you can expunge the associated backups.

If you run the script without the -expunge switch, the script will only display what it would delete. Use the -expunge switch to actually perform the deletions.

Output is written to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'expungeDataSpillageV2'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* expungeDataSpillageV2.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./expungeDataSpillageV2.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -search somefile.txt
```

The search results will be displayed. Other file names that are not an exact match may appear in the list. To narrow the search, you can use the -exactMatch switch:

```powershell
./expungeDataSpillageV2.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -search somefile.txt `
                            -exactMatch
```

To narrow the search to a specific object name, use the -objectName parameter:

```powershell
./expungeDataSpillageV2.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -search somefile.txt `
                            -objectName myvm `
                            -exactMatch
```

To narrow the search to a specific job name, use the -jobName parameter:

```powershell
./expungeDataSpillageV2.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -search somefile.txt `
                            -objectName myvm `
                            -jobName 'my protection job' `
                            -exactMatch
```

To show the versions where the file exists, use the -showVersions switch:

```powershell
./expungeDataSpillageV2.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -search somefile.txt `
                            -objectName myvm `
                            -jobName 'my protection job' `
                            -exactMatch `
                            -showVersions
```

You can limit the date range using the -olderThan and -newerThan parameters (days):

```powershell
./expungeDataSpillageV2.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -search somefile.txt `
                            -objectName myvm `
                            -jobName 'my protection job' `
                            -exactMatch `
                            -showVersions `
                            -olderThan 3 `
                            -newerThan 14
```

Finally, when you're happy with the list of backups that would be deleted, use the -expunge switch:

```powershell
./expungeDataSpillageV2.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -search somefile.txt `
                            -objectName myvm `
                            -jobName 'my protection job' `
                            -exactMatch `
                            -showVersions `
                            -olderThan 3 `
                            -newerThan 14 `
                            -expunge
```

## Authentication Parameters

* -vip: (optional) cluster to connect to (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -clusterName: (optional) cluster to connect to when connect to when connecting through Helios
* -mfaCode: (optional) OTP code for MFA

## Other Parameters

* -search: filename to search for
* -objectName: (optional) filter by object name
* -jobName: (optional) filter by job name
* -exactMatch: (optional) force search on exact file name
* -showVersions: (optional) show backup versions where file exists
* -olderThan: (optional) limit to versions older than X days
* -newerThan: (optional) limit to versions newer than X days
* -expunge: (optional) perform deletions

## Behavior and Caveats

The script will delete the local snapshots for objects (VMs, physical servers, NAS shares, etc) from protection runs where the searched file is present. Other objects in the protection run will not be deleted.

The script will also delete affected archives, but archives can not be deleted at the object level, so the `entire` archive for the protection run must be deleted.

The script does not delete replica backups from remote Cohesity clusters. The script will report about any remote clusters that are targets for replication, and you must run the script again on those clusters to search and expunge for the file that may have been replicated in.

The script relies on indexing to have been performed on the backups in order to perform the search. Any lack of indexes will cause files not to appear in search results.
