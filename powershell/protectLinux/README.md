# Protect Physical Linux Hosts using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds physical Linux servers to a file-based protection job.

**Warning:** The script will overwrite existing exclusions of a server if the server is included in the list of servers to process.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectLinux'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectLinux.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectLinux/protectLinux.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. Optionally create a text file called servers.txt and populate with the servers that you want to protect, like so (you can also specify servers on the command line):

```text
server1.mydomain.net
server2.mydomain.net
```

Note that the servers in the text file must be registered in Cohesity, and should match the name format as shown in the Cohesity UI.

Next optionally create a text file called inclusions.txt and populate with the paths that you want to include in the backup like so (you can also specify inclusions on the command line):

```text
/home
/var
```

Next optionally create a text file called exclusions.txt and populate with the folder paths that you want excluded from every server in the job, like so (you can also specify exclusions on the command line):

```text
/home/cohesityagent
/var/log
*.dbf
```

Then, run the main script like so:

```powershell
./protectLinux.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -jobName 'File-based Linux Job' `
                   -servers server1.mydomain.net, server2.mydomain.net `
                   -serverList .\serverlist.txt `
                   -inclusions /var, /home `
                   -inclusionList .\inclusions.txt `
                   -exclusions /var/log, /home/cohesityagent `
                   -exclusionList .\exclusions.txt `
                   -skipNestedMountPoints
```

```text
Connected!
Processing servers...
  server1.mydomain.net
  server2.mydomain.net
```

## Authentication Parameters

* -vip: (optional) name or IP of Cohesity cluster (defaults to helios.cohesity.com)
* -username: (optional) name of user to connect to Cohesity (defaults to helios)
* -domain: (optional) your AD domain (defaults to local)
* -useApiKey: (optional) use API key for authentication
* -password: (optional) will use cached password or will be prompted
* -noPrompt: (optional) do not prompt for password
* -tenant: (optional) organization to impersonate
* -mcm: (optional) connect through MCM
* -mfaCode: (optional) TOTP MFA code
* -emailMfaCode: (optional) send MFA code via email
* -clusterName: (optional) cluster to connect to when connecting through Helios or MCM

## Other Parameters

* -jobName: name of protection job
* -servers: (optional) one or more servers (comma separated) to add to the proctection job
* -serverList: (optional) text file containing list of servers (one per line)
* -inclusions: (optional) one or more inclusion paths (comma separated) defaults to /
* -inclusionList: (optional) a text file list of paths to include (one per line)
* -exclusions: (optional) one or more exclusion paths (comma separated)
* -exclusionList: (optional) a text file list of exclusion paths (one per line)
* -metadataFile: (optional) path to directive file (e.g. /home/myuser/directive.txt)
* -skipNestedMountPointTypes: (optional) (6.4 and above) comma separated list of mount point types to skip (e.g. nfs, xfs)
* -replaceRules: (optional) if omitted, inclusions/exclusions are appended to existing server rules (if any)
* -allServers: (optional) inclusions/exclusions are applied to all servers in the job
* -allLocalDrives: (optional) backup all local volumes

## New Job Parameters

* -policyName: (optional) name of protection policy to use
* -startTime: (optional) e.g. '18:30' (defaults to 8PM)
* -timeZone: (optional) e.g. 'America/New_York' (default is 'America/Los_Angeles')
* -incrementalSlaMinutes: (optional) default 60
* -fullSlaMinutes: (optional) default is 120
* -storageDomainName: (optional) default is 'DefaultStorageDomain'
* -paused: (optional) pause future runs (new job only)
* -qosPolicy: (optional) kBackupHDD or kBackupSSD (default is kBackupHDD)
* -preScript: (optional) name of pre script
* -preScriptArgs: (optional) arguments for pre script
* -preScriptTimeout: (optional) timeout for pre script (default is 900 seconds)
* -preScriptFail: (optional) fail backup if pre script fails
* -postScript: (optional) name of post script
* -postScriptArgs: (optional) arguments for post script
* -postScriptTimeout: (optional) timeout for post script (default is 900 seconds)
