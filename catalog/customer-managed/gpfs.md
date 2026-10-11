# Customer-Managed — GPFS

[← Back to Customer-Managed](index.md)

Total scripts: **7**

## Cluster Create (2)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [swapGpfsNode.ps1](https://github.com/cohesity/community-automation-samples/tree/main/powershell/swapGpfsNode) | PowerShell | 2024-11-04 | This PowerShell script replaces a protected GPFS node in a physical file-based protection group. |
| [swapGpfsNode.py](https://github.com/cohesity/community-automation-samples/tree/main/python/swapGpfsNode) | Python | 2024-11-04 | This script replaces a protected GPFS node in a physical file-based protection group. |

## Protection & Recovery (5)

| Script | Language | Date Last Updated | Use Case |
| --- | --- | --- | --- |
| [postscript.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/gpfs_snap_mounter) | Bash/Shell | 2024-11-04 | These bash scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of GPFS nodes to mount the latest snapshot for any protected file set to a consistent mount path. The assumption is that new snapshots are being created on a schedule by another process. |
| [postscript.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/gpfs_snapper) | Bash/Shell | 2024-11-04 | These bash scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of GPFS nodes to snapshot file sets prior to the backup starting, and deleting those snapshots when the backup is complete. |
| [prescript.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/gpfs_snap_mounter) | Bash/Shell | 2024-11-04 | These bash scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of GPFS nodes to mount the latest snapshot for any protected file set to a consistent mount path. The assumption is that new snapshots are being created on a schedule by another process. |
| [prescript.sh](https://github.com/cohesity/community-automation-samples/tree/main/bash/gpfs_snapper) | Bash/Shell | 2024-11-04 | These bash scripts can be used as a Pre and Post Scripts in a Cohesity Physical File-based backup of GPFS nodes to snapshot file sets prior to the backup starting, and deleting those snapshots when the backup is complete. |
| [protectGPFS.py](https://github.com/cohesity/community-automation-samples/tree/main/python/protectGPFS) | Python | 2024-11-04 | This script adds GPFS file sets to a file-based protection job. |
