# Customer-Managed — AWS

[← Back to Customer-Managed](README.md)

Total scripts: **12**

## Cloud Infrastructure (4)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [awsce_control.sh](https://github.com/cohesity/community-automation-samples/tree/main/python/powerCycleAWS) | Bash/Shell | 2024-11-04 | This python script gracefully powers on/off a Cohesity Cloud Edition cluster in AWS. (the main bash script) |
| [powerCycleAWS.py](https://github.com/cohesity/community-automation-samples/tree/main/python/powerCycleAWS) | Python | 2024-11-04 | This python script gracefully powers on/off a Cohesity Cloud Edition cluster in AWS. (the main bash script) |
| [storePassword.py](https://github.com/cohesity/community-automation-samples/tree/main/python/powerCycleAWS) | Python | 2024-11-04 | This python script gracefully powers on/off a Cohesity Cloud Edition cluster in AWS. (script to store passwords) |
| [waitForJob.py](https://github.com/cohesity/community-automation-samples/tree/main/python/powerCycleAWS) | Python | 2024-11-04 | This python script gracefully powers on/off a Cohesity Cloud Edition cluster in AWS. (waits for inbound replication to complete before poweroff) |

## Protection & Recovery (6)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [cloneVmToAws.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVmToAws) | PowerShell | 2024-11-04 | This powershell script recovers a VM to an AWS EC2 instance. |
| [cloneVmToAwsPlusPitDb.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVmToAwsPlusPitDb) | PowerShell | 2024-11-04 | This script demonstrates how to perform a clone of a VMware VM to AWS EC2, and then perform a SQL database recovery onto it. |
| [importAWSCSMJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/importAWSCSMJobs) | PowerShell | 2024-11-04 | These scripts export and import Cohesity AWS CSM Protection Jobs and sources, to serve as a method of migrating these jobs from one cluster to another. |
| [protectEC2VMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectEC2VMs) | PowerShell | 2026-09-30 | This powershell script adds EC2 VMs to a new or existing protection group. |
| [restoreEC2VM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreEC2VM) | PowerShell | 2025-11-25 | This powershell script recovers a VM in AWS EC2. |
| [updateAWSCredentials.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateAWSCredentials) | Python | 2024-11-04 | This script updates the acess key and secret key in an AWS source registration. |

## Reporting & Analytics (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [awsProtectedObjectsByTag.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/awsProtectedObjectsByTag) | Python | 2026-07-23 | This script reports on Cohesity-protected AWS objects (EC2 instances and RDS databases) and includes each object's **AWS resource tags** (the tags assigned in AWS itself, e.g. `Environment=Production`, `CostCenter=1234`) in the output. You can optionally filter the report to only objects that carry a specific tag key, or a specific key/value pair. |

## Views & Storage (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [exportAWSCSMJobs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/importAWSCSMJobs) | PowerShell | 2024-11-04 | These scripts export and import Cohesity AWS CSM Protection Jobs and sources, to serve as a method of migrating these jobs from one cluster to another. |
