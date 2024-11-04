# Create and Configure VE using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script performs cluster create and sets various post create configuration options for a single-node virtual edition of Cohesity.

## Download the scripts

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$dirName = 'clusterCreateAndConfigVE'
$scriptName = 'clusterCreateAndConfigVE'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$dirName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'clusterCreateVE'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$dirName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'configVE'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$dirName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'example-clusterCreateVE'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$dirName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'example-clusterCreateAndConfigVE'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$dirName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
$scriptName = 'example-configVE'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$dirName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [clusterCreateAndConfigVE.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/clusterCreateAndConfigVE/clusterCreateAndConfigVE.ps1): the main PowerShell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module
* [example-clusterCreateAndConfigVE.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/clusterCreateAndConfigVE/example-clusterCreateAndConfigVE.ps1): example syntax
* [clusterCreateVE.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/clusterCreateAndConfigVE/clusterCreateVE.ps1): Only performs the cluster create part
* [example-clusterCreateVE.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/clusterCreateAndConfigVE/example-clusterCreateVE.ps1): example syntax
* [configVE.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/clusterCreateAndConfigVE/configVE.ps1): Only performs the cluster config part
* [example-configVE.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/clusterCreateAndConfigVE/example-configVE.ps1): example syntax

Place the files in a folder together, and modify the example script to fit your environment.

## Parameters

* -ip: ip address of the node
* -netmask: subnet mask
* -gateway: default gateway
* -dnsServers: dns servers (comma separated)
* -ntpServers: ntp servers (comma separated)
* -clusterName: Cohesity cluster name
* -clusterDomain: DNS domain of Cohesity cluster
* -pwd: new admin password
* -adminEmail: admin email address
* -adDomain: AD domain to join
* -adOu: canonical path of container/OU to create computer account (e.g. Servers/Cohesity)
* -preferredDC: preferred domain controller(s) (comma separated)
* -adAdmin: AD admin account name
* -adPwd: AD admin password
* -adAdminGroup: AD admin group to add
* -timezone: timezone
* -smtpServer: smtp server address
* -supportPwd: support account new ssh password
* -alertEmail: email address for critical alerts
