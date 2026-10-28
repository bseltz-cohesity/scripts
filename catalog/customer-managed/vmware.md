# Customer-Managed — VMware

[← Back to Customer-Managed](README.md)

Total scripts: **48**

## Monitoring & Alerting (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [shutdownVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/vmware/python/shutdownVMs) | Python | 2026-03-02 | This script performs a graceful shutdown of the specified VMs, then monitors until the shutdowns are complete. |

## Other / Utility (2)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [powerOnVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/vmware/python/powerOnVMs) | Python | 2026-03-01 | This script powers on the specified VMs. |
| [vCenterTest.py](https://github.com/cohesity/community-automation-samples/tree/main/python/vCenterTest) | Python | 2024-11-04 | This script performs a simple authentication to vCenter to test connectivity and credentials. |

## Protection & Recovery (36)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [addGlobalVMDiskExclusions.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/addGlobalVMDiskExclusions) | PowerShell | 2024-11-04 | This PowerShell script adds global disk exclusions to an existing VMware protection group. |
| [adHocProtectVM.py](https://github.com/cohesity/community-automation-samples/tree/main/python/adHocProtectVM) | Python | 2024-11-04 | This Python script temporarily adds VMware VMs to a new (temporary) or existing VM protection group, runs the group and then removes the VMs, to affect an ad hoc backup of the VMs. |
| [cloneVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVM) | PowerShell | 2026-03-24 | This powershell script clones one or more VMware VMs. |
| [cloneVMProtectionGroup.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/cloneVMProtectionGroup) | PowerShell | 2025-10-20 | This PowerShell script clones a VMware protection group. |
| [excludeVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/excludeVMs) | PowerShell | 2024-11-04 | This powershell script excludes one or more VMs from an existing protection job where parent containers are autoprotected. |
| [excludeVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/excludeVMs) | Python | 2024-11-04 | This python script applies exclusions to an autoprotect VM protection job. (the main python script (one job only)) |
| [excludeVMsAllJobs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/excludeVMs) | Python | 2024-11-04 | This python script applies exclusions to an autoprotect VM protection job. (alternate script (all jobs)) |
| [excludeVMsByTag.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/excludeVMsByTag) | PowerShell | 2024-11-04 | This PowerShell script excludes VMs from protection jobs by vSphere tag. |
| [expungeVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/expungeVM) | PowerShell | 2024-11-04 | This powershell script searches for a VM, and deletes all backups of that VM, including the local snapshots and archives. |
| [instantVolumeMount.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/instantVolumeMount) | PowerShell | 2024-11-04 | This script demonstrates how to perform an Instant Volume Mount using PowerShell. (the main powershell script) |
| [instantVolumeMount.py](https://github.com/cohesity/community-automation-samples/tree/main/python/instantVolumeMount) | Python | 2024-11-04 | This python script performs an Instant Volume Mount recovery to a VM or physical server. (the main python script) |
| [linux_vm_freeze_thaw.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/linux_vm_freeze_thaw) | Bash/Shell | 2024-11-04 | This bash script can be used as a VMTools Freeze/Thaw Script for a Cohesity VMware backup to freeze and thaw applications running in a Linux VM. |
| [listVMsInJobRun.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/listVMsInJobRun) | PowerShell | 2024-11-04 | This PowerShell script lists the VMs that were backed up by the past few runs of a protection job. |
| [protectedVMsWithExcludedDisks.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectedVMsWithExcludedDisks) | PowerShell | 2025-04-25 | This PowerShell script reports on protected VMs that have excluded disks. |
| [protectvApp.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectvApp) | PowerShell | 2024-11-04 | This PowerShell script adds a vCloud Director vApp to a new or existing SQL protection job. |
| [protectvApps.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectvApps) | Python | 2024-11-04 | This script protects all the vApps of a vCloud virtual datacenter. |
| [protectVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectVM) | PowerShell | 2025-12-25 | This powershell script adds VMs to a new or existing protection job. |
| [protectVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectVMs) | Python | 2026-09-24 | This script protects VMware VMs. |
| [protectVMsByCluster.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectVMsByCluster) | PowerShell | 2025-02-11 | This PowerShell script auto-protects VMs by vSphere cluster, adding to a new or existing protection group. |
| [protectVMsByContainer.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectVMsByContainer) | PowerShell | 2026-10-24 | This powershell script auto protects VMs by container. A Container can be a datacenter, cluster, host or folder. |
| [protectVMsByDatastore.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectVMsByDatastore) | PowerShell | 2024-11-04 | This PowerShell script adds all the VMs from a Datastore to a new or existing protection group. |
| [protectVMsByTag.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/protectVMsByTag) | PowerShell | 2025-02-11 | This PowerShell script adds include/exclude VM tags to a new or existing protection group. |
| [recoverVMs-csv.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs-csv) | Python | 2025-02-17 | This python script recovers VMs listed in a CSV file. |
| [recoverVMs-throttled.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs-throttled) | PowerShell | 2026-10-23 | This powershell script recovers a list of VMs and limits the number of concurrent restores to the specified limit. |
| [recoverVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverVMs) | PowerShell | 2025-05-01 | This powershell script recovers a list of VMs. |
| [recoverVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/recoverVMs) | Python | 2025-04-10 | This python script recovers one or more VMs. |
| [registerVcenter.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/registerVcenter) | PowerShell | 2024-11-04 | This powershell script registers vCenter as a protection source in Cohesity. |
| [registerVcenter.py](https://github.com/cohesity/community-automation-samples/tree/main/python/registerVcenter) | Python | 2024-12-09 | This script registers or updates a vCenter protection source. |
| [tearDownVolumeMount.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/instantVolumeMount) | PowerShell | 2024-11-04 | This script demonstrates how to perform an Instant Volume Mount using PowerShell. |
| [unprotectedVMs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/unprotectedVMs) | Python | 2024-11-04 | This script reports unprotected VMs. Output is written to a CSV file |
| [unprotectMissingVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectMissingVMs) | PowerShell | 2024-11-04 | This PowerShell script updates VMware protection jobs to remove missing VMs. |
| [unprotectVM.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/unprotectVM) | PowerShell | 2024-11-04 | This PowerShell script removes VMs from protection groups. |
| [unprotectVM.py](https://github.com/cohesity/community-automation-samples/tree/main/python/unprotectVM) | Python | 2024-11-04 | This script removes VMs from protection groups. Note that this will not work with autoprotected VMs, only VMs that are explicitely added to protection gorups. |
| [updateVcenterCredentials.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/updateVcenterCredentials) | PowerShell | 2024-11-04 | This powershell script updates credentials for a vCenter protection source. |
| [updateVcenterCredentials.py](https://github.com/cohesity/community-automation-samples/tree/main/python/updateVcenterCredentials) | Python | 2024-11-04 | This script updates the username and password in a vcenter source registration. |
| [validateVMBackups.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/validateVMBackups) | PowerShell | 2024-11-20 | This PowerShell script validates backups for virtual servers. The script will generate an html report and send it to email recipients. The validation process instructs the cluster to mount the latest backup and retrieve a volume listing. If the retrieval is successful, the backup is considered valid. |

## Reporting & Analytics (9)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [clusterNumberOfProtectedVMs.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/clusterNumberOfProtectedVMs) | PowerShell | 2024-11-04 | This PowerShell script reports the number of VMs protected by one or more Cohesity clusters. |
| [dataReadPerVMReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/dataReadPerVMReport) | Python | 2024-11-04 | This python script creates a report of data read/written per VM. Note that this report performs some estimations so is not expected to be completely accurate. |
| [emptyVMProtectionGroups.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/emptyVMProtectionGroups) | Python | 2025-12-04 | This python script reports VM protection groups that backed up zero VMs. |
| [vmAvgDiskThroughput.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/vmAvgDiskThroughput) | PowerShell | 2024-11-04 | This script collects average VM disk throughput needed to size CDP solutions. This script requires vSphere PowerCLI. |
| [vmJobSelections.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/vmJobSelections) | PowerShell | 2026-10-15 | This PowerShell script reports on the VMs protected by protection jobs. |
| [vmMacAddresses.py](https://github.com/cohesity/community-automation-samples/tree/main/vmware/python/vmMacAddresses) | Python | 2026-03-01 | This script reports the MAC addresses of network adapters of the specified VMs. |
| [vmProtectionReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/vmProtectionReport) | PowerShell | 2024-11-04 | This powershell generates a VM protection report. |
| [vmRecoveryReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/vmRecoveryReport) | PowerShell | 2025-02-10 | This PowerShell script script creates a VM Recovery report. |
| [vmRecoveryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/vmRecoveryReport) | Python | 2025-02-05 | This python script creates a VM Recovery report. |
