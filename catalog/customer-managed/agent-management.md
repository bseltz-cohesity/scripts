# Customer-Managed — Agent Management

[← Back to Customer-Managed](index.md)

Total scripts: **20**

## Agent Management (16)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [agentCertificateCheck.py](https://github.com/cohesity/community-automation-samples/tree/main/python/agentCertificateCheck) | Python | 2024-11-04 | This script will report certificate expirations for registered agents. The script will output two files: `agentCertificateCheck-clusterName-DateTime.csv` will contain a detailed report, and `impactedAgents-clusterName-dateTime.txt` will contain the names of agents that require urgent upgrade. The text file can be used as input to the upgradeAgents.py script: <https://github.com/cohesity/community-automation-samples/tree/main/python/upgradeAgents> |
| [agentGflags.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/agentGflags) | PowerShell | 2024-11-04 | This powershell script lists or sets agent gFlags. |
| [agentGflags.py](https://github.com/cohesity/community-automation-samples/tree/main/python/agentGflags) | Python | 2024-11-04 | This python script sets Cohesity agent gflags on linux hosts, via SSH. |
| [deployLinuxAgent.py](https://github.com/cohesity/community-automation-samples/tree/main/python/deployLinuxAgent) | Python | 2026-05-25 | This python script deploys the Cohesity Linux agent on remote hosts via SSH. |
| [deployWindowsAgent.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deployWindowsAgent) | PowerShell | 2024-12-16 | This PowerShell script installs and configures the Cohesity Windows agent on remote hosts. This is useful when deploying the agent on new hosts. After the agent is installed, Cohesity can push out agent upgrades from the UI. (the main powershell script) |
| [deployWindowsAgentSimple.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/deployWindowsAgentSimple) | PowerShell | 2024-12-16 | This powershell script installs and configures the Cohesity Windows agent on remote hosts. This is useful when deploying the agent on new hosts. After the agent is installed, Cohesity can push out aget upgrades from the UI. (the main powershell script) |
| [detachLinuxAgent.py](https://github.com/cohesity/community-automation-samples/tree/main/python/detachLinuxAgent) | Python | 2024-11-04 | This python script updates the Cohesity agent configuration on a Linux host, to disassociate it from its cluster. |
| [detachWindowsAgent.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/detachWindowsAgent) | PowerShell | 2026-01-27 | This PowerShell decouples a Windows agent from a cohesity cluster so that it can be registered to another cluster. |
| [generateAgentCertificate.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/generateAgentCertificate) | PowerShell | 2024-11-04 | This PowerShell script generates a new agent certificate. |
| [generateAgentCertificate.py](https://github.com/cohesity/community-automation-samples/tree/main/python/generateAgentCertificate) | Python | 2024-11-04 | This python script generates a new agent certificate. |
| [replaceLinuxAgentCertificate.py](https://github.com/cohesity/community-automation-samples/tree/main/python/replaceLinuxAgentCertificate) | Python | 2024-11-04 | This python script replaces the Cohesity agent certificate on a Linux host. |
| [replaceWindowsAgentCertificate.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/replaceWindowsAgentCertificate) | PowerShell | 2024-11-04 | This PowerShell replaces the Cohesity agent certificate on a Windows host. |
| [resetBSODCounters.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/resetBSODCounters) | PowerShell | 2024-11-04 | This PowerShell script performs remote registry edit of the BSOD counter and restarts the Cohesity agent. The script will by default query Cohesity to find servers protected by a block-based physical protection group and performs those actions on each server. Alternatively you can provide server names using the optional parameters. |
| [upgradeAgents.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/upgradeAgents) | PowerShell | 2024-11-04 | This PowerShell script detects and upgrades any upgradable agents for physical protection sources registered to the Cohesity cluster. This script can be run from anywhere that can connect to the Cohesity clusters(s) or can connect to helios. |
| [upgradeAgents.py](https://github.com/cohesity/community-automation-samples/tree/main/python/upgradeAgents-test) | Python | 2024-11-04 | pyhesity.py contains a set of functions that make it easy to use the Cohesity REST API, including functions for authentication, making REST calls, and managing date formats. |
| [upgradeAgents.py](https://github.com/cohesity/community-automation-samples/tree/main/python/upgradeAgents) | Python | 2024-11-04 | This script will initiate upgrade for registered agents. |

## Reporting & Analytics (4)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [agentSummaryReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/agentSummaryReport) | PowerShell | 2025-07-11 | This PowerShell script creates an agent summary report. |
| [agentSummaryReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/agentSummaryReport) | Python | 2024-11-04 | This python script creates an agent summary report. |
| [agentVersions.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/agentVersions) | PowerShell | 2025-06-24 | This powershell script lists the version of the installed Cohesity agent on every physical server registered on the cluster |
| [agentVersions.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/agentVersions) | Python | 2025-05-19 | This Python script generates a report of agent versions of registered physical sourcesoutputs to a TSV file. |
