# Clone a VMware VM to an AWS EC2 Instance using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script recovers a VM to an AWS EC2 instance.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'cloneVmToAws'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [cloneVmToAws.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cloneVmToAws/cloneVmToAws.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place the files in a folder together and run the main script like so:

```powershell
./cloneVmToAws.ps1 -vip mycluster `
                   -username myusername `
                   -domain mydomain.net `
                   -vmName myvm `
                   -prefix 'restore-' `
                   -powerOn `
                   -awsSource '378341872752/MyUser' `
                   -region 'us-east-2' `
                   -vpc 'vpc-0986e77382e8aa445' `
                   -subnet 'subnet-08fc87d5c93439815' `
                   -securityGroup 'sg-0800ea566835b2ddd' `
                   -instanceType 't2.micro' `
                   -recoverDate '2021-12-15 16:11' `
                   -wait
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username (e.g. admin)
* -domain: (optional) Active Directory domain (defaults to 'local')
* -vmName: Name of VM to recover
* -recoverDate: (optional) e.g. '2021-08-18 23:30:00' (will use most recent at or before this date)
* -prefix: (optional) add a prefix to the VM name during restore
* -poweron: (optional) power on the VMs during restore (default is false)
* -awsSource: AWS protection source to recover to
* -region: AWS region to restore to
* -vpc: AWS VPC ID to restore to
* -subnet: AWS subnet ID to restore to
* -securityGroup: existing security group to use
* -instanceType: AWS instance type to use (e.g. t2.micro)
* -wait: (optional) wait for completion and return new instance IP address
