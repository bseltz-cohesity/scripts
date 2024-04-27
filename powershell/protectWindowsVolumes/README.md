# Protect Physical Windows Volumes

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds physical Windows servers to a volume-based protection job.

This script is compatible with Cohesity 6.5.1 and later.

**Warning:** The script will overwrite existing inclusions and exclusions of a server if the server is included in the list of servers to process.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectWindowsVolumes'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [protectWindowsVolumes.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/protectWindowsVolumes/protectWindowsVolumes.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place all files in a folder together. Optionally create a text file called servers.txt and populate with the servers that you want to protect, like so (you can also specify servers on the command line):

```text
server1.mydomain.net
server2.mydomain.net
```

Note that the servers in the text file must be registered in Cohesity, and should match the name format as shown in the Cohesity UI.

Then, run the main script like so:

If you want to protect all volumes:

```powershell
./protectWindowsVolumes.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -servers server1.mydomain.net, server2.mydomain.net `
                            -jobName 'Block-based Windows Job'
```

If you want to explicitly include volumes (excluding any volumes not included):

```powershell
./protectWindowsVolumes.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -servers server1.mydomain.net, server2.mydomain.net `
                            -jobName 'Block-based Windows Job' `
                            -inclusions C:\, E:\, 'System Reserved'
```

or if you want to explicitly exclude volumes (including any volumes that are not excluded):

```powershell
./protectWindowsVolumes.ps1 -vip mycluster `
                            -username myusername `
                            -domain mydomain.net `
                            -servers server1.mydomain.net, server2.mydomain.net `
                            -jobName 'Block-based Windows Job' `
                            -exclusions F:\, G:\, 'System Reserved'
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -jobName: name of protection job
* -servers: one or more servers (comma separated) to add to the proctection job
* -serverList: file containing list of servers
* -inclusions: inclusion paths (comma separated)
* -inclusionList: a text file list of paths to include (one per line)
* -exclusions: one or more exclusion paths (comma separated)
* -exclusionList: a text file list of exclusion paths (one per line)
