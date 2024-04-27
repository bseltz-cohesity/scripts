# Restore an AWS EC2 VM using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a VM in AWS EC2.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'restoreEC2VM'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [restoreEC2VM.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/restoreEC2VM/restoreEC2VM.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together, then you can run the script.

To restore a VM to its original location in AWS:

```powershell
./recstoreEC2VM.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -instanceName myvm `
                    -powerOn `
                    -originalLocation
```

To restore a VM to an alternate location in AWS:

```powershell
./recstoreEC2VM.ps1 -vip mycluster `
                    -username myusername `
                    -domain mydomain.net `
                    -instanceName myvm `
                    -powerOn `
                    -awsSource '123456789012/Cohesity' `
                    -region 'us-east-1' `
                    -keyPair 'mykey' `
                    -vpc 'vpc-01234567890123456' `
                    -subnet 'subnet-01234567890123456' `
                    -securityGroup 'sg-01234567890123456'
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -instanceName: Name of VM to recover
* -prefix: (optional) add a prefix to the VM name during restore (default is 'restore-')
* -powerOn: (optional) will remain powered off if omitted
* -originalLocation: (optional) if omitted then alternate location parameters required
* -wait: (optional) monitor for completion and report final status of restore

## Alternate Location Parameters

* -awsSource: (optional) name of AWS protection source to restore to
* -region: (optional) name of AWS region to restore to
* -keyPair: (optional) name of key pair to apply to restored VM
* -vpc: (optional) ID of VPC to restore to
* -subnet: (optional) ID of subnet to attach restored VM to
* -securityGroup: (optional) ID of security group to attach restored VM to
