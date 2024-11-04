# Redundant Protection Report using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script gathers a report of objects that are protected by multiple protectionJobs. The report is displayed on the screen and also saved to a CSV file.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'redundantProtectionReport'
$repoURL = 'https://raw.githubusercontent.com/cohesity/community-automation-samples/main'
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/reports/powershell/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -UseBasicParsing -Uri "$repoUrl/powershell/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* [redundantProtectionReport.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/reports/powershell/redundantProtectionReport/redundantProtectionReport.ps1): the main powershell script
* [cohesity-api.ps1](https://raw.githubusercontent.com/cohesity/community-automation-samples/main/powershell/cohesity-api/cohesity-api.ps1): the Cohesity REST API helper module

Place both files in a folder together, then we can run the script like so.

```powershell
./redundantProtectionReport.ps1 -vip 10.99.1.67 -username admin [ -domain local ]
```
```text
Connected!

Collecting Report of Objects Protected by Multiple Jobs...

Object (Type) Jobs
------------------

\\10.99.1.190\e$ (GenericNas)
	NAS Backup
	NAS_SMB
ame-centos7-01 (VMware)
	dans VMs
	DemoJob
	DOug
	MSU
	Tarek_Prod_Gold
anoop-centos7-1 (VMware)
	2VMlegalhold1later
	Tarek Cloud Test
	Testcp - DO NOT auto-protect entire vCenter
anoop-centos7-1tr5 (VMware)
	2VMlegalhold1later
	Testcp - DO NOT auto-protect entire vCenter
anoop-centos7-2 (VMware)
	Anoop-VMs
	Testcp - DO NOT auto-protect entire vCenter
anoop-win2012 (VMware)
	Anoop-VMs
	Testcp - DO NOT auto-protect entire vCenter
	TestLabgroup
	Tweddle
bb-win7 (VMware)
	DemoJob
	DOug
	selab2 Demo Policy - VMware
	Tarek_Prod_Gold
BSeltz-CentOS1 (VMware)
	BSeltz-Demo1
	Testcp - DO NOT auto-protect entire vCenter
	vcenter test job
BSeltz-CentOS2 (VMware)
	BSeltz-Demo1
	Testcp - DO NOT auto-protect entire vCenter
	vcenter test job
BSeltz-CentOS3 (VMware)
	BSeltz-Demo1
	Testcp - DO NOT auto-protect entire vCenter
	vcenter test job
BSeltz-Win2012 (VMware)
	BSeltz-Demo1
	Testcp - DO NOT auto-protect entire vCenter
	vcenter test job
centos-vm-01 (VMware)
	JussiVM
	TEST_JW
centos07-BB (VMware)
	bb_delete
	selab2 Demo Policy - VMware
centos7vm1 (VMware)
	dans VMs
	MyFancyNewBackupJob
	selab2 Demo Policy - VMware
	Umpqua VMs
CentOSVM (VMware)
	DataLock Job
	Testcp - DO NOT auto-protect entire vCenter
DoNotRunAutoProtectOnWholeESXSvr (VMware)
	AZtest
	Testcp - DO NOT auto-protect entire vCenter
JZ-Win2k12 (VMware)
	Testcp - DO NOT auto-protect entire vCenter
	Win2k C Drive
pb_ora-linux01 (VMware)
	pb_vm-tag
	Testcp - DO NOT auto-protect entire vCenter
pb-centos (VMware)
	pb_tenant-a
	Testcp - DO NOT auto-protect entire vCenter
pb-ra (View)
	pb_ra
	PB-view
pb-win (VMware)
	pb-sql
	Testcp - DO NOT auto-protect entire vCenter
Win2012-df (VMware)
	Heart-prot-App-A
	MyFancyNewBackupJob
win2012-sql (VMware)
	SQL Gold - lab2
	SQL Gold - lab3
windows2012 (VMware)
	Abela Demo Job
	Demo_Azure
	MyFancyNewBackupJob
windows7_116 (VMware)
	Abela Demo Job
	Heart-prot-App-A
WindowsBT (VMware)
	Testcp - DO NOT auto-protect entire vCenter
	Thorpe Demo Job
WindowsTM (VMware)
	dans VMs
	MyFancyNewBackupJob

Output Saved to 10.99.1.67-redundantProtectionReport.csv

```
