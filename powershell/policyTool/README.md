# Manage Protection Policies using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script creates and edits protection policies.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'policyTool'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [policyTool.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/policyTool/policyTool.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

To list policies:

```powershell
./policyTool.ps1 -vip mycluster `
                 -username myusername `
                 -domain mydomain.net
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
* -noAuth: (optional) use existing authentication to cluster

## Other Parameters

* -policyName: (optional) name of policy to create or edit
* -action: (optional): list, create, edit, delete, addfull, deletefull, addextension, deleteextension, logbackup, addreplica, deletereplica, addarchive, deletearchive, editretries (default is list
* -retention: (optional) number of days/weeks/years to retain
* -retentionUnit: (optional) days, weeks, months, years (default is days)
* -frequency: (optional) frequency of backup (default is 1)
* -frequencyUnit: (optional) runs, minutes, hours, days, weeks, months, years (default is runs)
* -dayOfWeek: (optional) one or more weekdays (comma separated) default is Sunday
* -weekOfMonth: (optional) First, Second, Third, Fourth, Last (default is first)
* -retries: (optional) default is 3
* -retryMinutes: (optional) number of minutes to wait between retries (default is 5)
* -lockDuration: (optional) datalock duration (requires data security role to edit)
* -lockUnit: (optional) days, weeks, months, years (default is days) (requires data security role to edit)
* -addQuietTime: (optional) one or more quiet times to add (comma separated) see quiet time format below
* -removeQuietTime: (optional) one or more quiet times to remove (comma separated) see quiet time format below
* -targetName: (optional) name of remote cluster or external target
* -deleteAll: (optional) delete all replications/archives for the specified target

## Behavior

The script performs one action at a time. So If you want to create a new policy, use `-action create` and it will create the local policy with base retention.

If you then want to add extended retention, a replication target, an archive target, a log backup, etc, then run the script again for each of these you want to add.

## Quiet Time Format

Quite times can be entered as a quoted string in the format:

`"days;startTime;endTime"`

For example:

`"Saturday,Sunday;00:00;02:30"`

To specify all days of the week, use 'All':

`"All;00:00;02:30"`

To add or remove multiple quite times, enter a comma separated list of quiet times:

`"Saturday,Sunday;00:00;02:30", "Saturday,Sunday;23:00;23:30"`
