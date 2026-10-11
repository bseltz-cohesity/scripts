# Customer-Managed — Support

[← Back to Customer-Managed](index.md)

Total scripts: **10**

## Cluster & System Administration (6)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [collectTimeCapsule.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/collectTimeCapsule) | PowerShell | 2026-09-24 | This script collects a Cohesity Timecapsule (support bundle), then downloads it locally. |
| [collectTimeCapsule.py](https://github.com/cohesity/community-automation-samples/tree/main/python/collectTimeCapsule) | Python | 2026-09-24 | This script collects a Cohesity Timecapsule (support bundle), then downloads it locally. |
| [enableRT.py](https://github.com/cohesity/community-automation-samples/tree/main/python/scheduleRT) | Python | 2024-11-04 | This python script schedules the opening of Cohesity support channel for some time in the future, and sets how long support channel will remain open. This allows the customer to, for example, schedule secure channel now, to open after hours for a few hours, such that Cohesity support can access the customer's Cohesity cluster in the evening. (the script that runs as scheduled) |
| [scheduleRT.py](https://github.com/cohesity/community-automation-samples/tree/main/python/scheduleRT) | Python | 2024-11-04 | This python script schedules the opening of Cohesity support channel for some time in the future, and sets how long support channel will remain open. This allows the customer to, for example, schedule secure channel now, to open after hours for a few hours, such that Cohesity support can access the customer's Cohesity cluster in the evening. (the main python script to set the schedule) |
| [supportChannel.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/supportChannel) | PowerShell | 2026-09-28 | This PowerShell script enables and disables support channel on a cluster. |
| [supportChannel.py](https://github.com/cohesity/community-automation-samples/tree/main/python/supportChannel) | Python | 2026-09-28 | This script enables, disables or extends support channel. |

## Other / Utility (1)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [scheduleHealer.py](https://github.com/cohesity/community-automation-samples/tree/main/python/scheduleHealer) | Python | 2024-11-04 | This python script schedules an Apollo healer run (which will expidite garbage collection). |

## User, Access & Security (3)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [obfuscateLogs.py](https://github.com/cohesity/community-automation-samples/tree/main/python/obfuscateLogs) | Python | 2026-10-02 | This script will obfuscate file paths, filenames, directory names, entity/path identifiers, MAC addresses, and certificate/key fingerprints in log files, plus any additional custom rules you supply (e.g. IP addresses, hostnames, URLs). The script will unzip/re-zip and untar/tar gz and tar files. |
| [supportUserPassword.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/supportUserPassword) | PowerShell | 2025-12-02 | This powershell script will set/update the support user password. |
| [supportUserPassword.py](https://github.com/cohesity/community-automation-samples/tree/main/python/supportUserPassword) | Python | 2025-04-29 | This python script will set/update the support user password. |
