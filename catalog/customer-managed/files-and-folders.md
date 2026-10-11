# Customer-Managed — Files & Folders

[← Back to Customer-Managed](README.md)

Total scripts: **21**

## Other / Utility (4)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [extensionFinder.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/extensionFinder) | PowerShell | 2024-11-04 | This powershell script searches for files with the file name extensions listed in a text file. The output will be written to a CSV file. |
| [fileSearch.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/fileSearch) | PowerShell | 2026-05-26 | This PowerShell script searches for a file and displays the results. |
| [fileSearch.py](https://github.com/cohesity/community-automation-samples/tree/main/python/fileSearch) | Python | 2026-06-02 | This Python script searches for a file and displays the results. |
| [findFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/findFiles) | PowerShell | 2026-01-08 | This powershell script searches for files with the specified file extension |

## Protection & Recovery (11)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [downloadFile.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/downloadFile) | PowerShell | 2024-11-04 | This powershell downloads a file from a backup on Cohesity |
| [downloadFile.py](https://github.com/cohesity/community-automation-samples/tree/main/python/downloadFile) | Python | 2024-11-04 | This python script downloads a file from a Cohesity backup. |
| [downloadZipFile.py](https://github.com/cohesity/community-automation-samples/tree/main/python/downloadZipFile) | Python | 2024-11-04 | This script downloads and extracts a recovered zip file from a file-level recovery from archive. |
| [recoverFileScheduled.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/recoverFileScheduled) | PowerShell | 2025-03-04 | This powershell script searches for and downloads a file. If run on a schedule it will also delete old versions of the file. |
| [restoreFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreFiles) | PowerShell | 2026-10-05 | This powershell script restores files from physical server backups. |
| [restoreFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreFiles) | Python | 2025-10-16 | This python script restores files from a Cohesity physical server or NAS backup. |
| [restoreFolder.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/restoreFolder) | Bash/Shell | 2024-11-04 | This bash script performs a restore of a folder from one physical server to another. |
| [restoreOneDriveFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreOneDriveFiles) | PowerShell | 2024-11-04 | This PowerShell script restores OneDrive files. |
| [restorePhysicalFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restorePhysicalFiles) | Python | 2025-05-28 | This python script restores files from a Cohesity physical server backup. |
| [restoreVMFiles.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/restoreVMFiles) | PowerShell | 2025-08-05 | This powershell script restores files from a VMware or AHV VM backup. |
| [restoreVMFiles.py](https://github.com/cohesity/community-automation-samples/tree/main/python/restoreVMFiles) | Python | 2025-06-16 | This python script restores files from a VMware VM backup. |

## Reporting & Analytics (6)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [backedUpFileList.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/backedUpFileList) | PowerShell | 2025-01-23 | This PowerShell script enumerates the files that are available for restore from the specified server/job. The file list is written to an output text file. |
| [backedUpFileList.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backedUpFileList) | Python | 2025-02-25 | This Python script enumerates the files that are available for restore from the specified server/job. The file list is written to an output text file and also a CSV file. |
| [backedUpFileListJSON.py](https://github.com/cohesity/community-automation-samples/tree/main/python/backedUpFileListJSON) | Python | 2025-07-18 | This Python script enumerates the files that are available for restore from the specified server/job. The file list is written to stdout as JSON. |
| [Find-GitHubFile.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/Find-GitHubFile) | PowerShell | 2026-08-24 | This PowerShell script fuzzy-searches the files in a GitHub repo, similar to GitHub's own "Go to file" search box. Given one or more search terms, it pulls the repo's file tree via the GitHub API, finds every path that contains all of the terms as a literal, case-insensitive substring, and prints the matches along with a link to the enclosing folder on GitHub. The file tree is cached locally for a few minutes so repeated searches against the same repo/branch don't keep hitting the API. |
| [restoreFilesReport.ps1](https://github.com/cohesity/community-automation-samples/tree/main/reports/powershell/restoreFilesReport) | PowerShell | 2025-02-11 | This script sends an HTML-formatted restore report to Email recipients |
| [restoreFilesReport.py](https://github.com/cohesity/community-automation-samples/tree/main/reports/python/restoreFilesReport) | Python | 2025-02-11 | This Python script creates a report of file-based restores. Output is saved to HTML and CSV files. |
