# Snapshot Cleanup Scripts

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

These scripts help cleanup azure snapshots. You can use which ever script is compatible with your environment.

Contributor: Kanak Agarwal

## Prerequisites

1. Application Id.
2. Service Principal Key.
3. Tenant Id.
4. Number Of Days Snapshots should be older.
5. Job Id (optional).

Note: Application Id being used must have enough permissions to list and delete snapshots.

## Scripts

1. azure_cloud_shell_compatible_cleanup_script.sh

    Additional prerequisites:
        - Azure Cloud Shell
        - Bash

    Steps:
    1. Create new blank file using azure cloud shell and name it as azure_cloud_shell_compatible_cleanup_script.sh
    2. Copy the contents of script.
    3. chmod +x azure_cloud_shell_compatible_cleanup_script.sh
    4. Execute the script (./azure_cloud_shell_compatible_cleanup_script.sh)

    Script Execution:
    1. On prompt enter Application Id, Principal Key, Tenant Id, Number Of Days Snapshots should be older, Job Id for which you want to filter snapshots (optional).
    2. List of snapshots would be displayed, if you wish to delete whole list type "YES" for any other input it cancels.
    Note: "YES" is case sensitive
    3. If YES is entered, all snapshots gets deleted.

2. powershell_compatible_cleanup_script.ps1

    Additional prerequisites:
        - Azure Cli must be installed.
        - Powershell

    Steps:
    1. Create new blank file using power shell and name it as powershell_compatible_cleanup_script.sh
    2. Copy the contents of script.
    3. chmod +x powershell_compatible_cleanup_script.sh
    4. Execute the script (./powershell_compatible_cleanup_script.sh)

    Script Execution:
    1. On prompt enter Application Id, Principal Key, Tenant Id, Number Of Days Snapshots should be older, Job Id for which you want to filter snapshots (optional).
    2. List of snapshots would be displayed, if you wish to delete whole list type "YES" for any other input it cancels.
    Note: "YES" is case sensitive
    3. If YES is entered, all snapshots gets deleted.

3. ubuntu_compatible_cleanup_script.sh

    Additional prerequisites:
        - Azure Cli must be installed.
        - Bash

    Steps:
    1. Create new blank file using power shell and name it as ubuntu_compatible_cleanup_script.sh
    2. Copy the contents of script.
    3. chmod +x ubuntu_compatible_cleanup_script.sh
    4. Execute the script (./ubuntu_compatible_cleanup_script.sh)

    Script Execution:
    1. On prompt enter Application Id, Principal Key, Tenant Id, Number Of Days Snapshots should be older, Job Id for which you want to filter snapshots (optional).
    2. List of snapshots would be displayed, if you wish to delete whole list type "YES" for any other input it cancels.
    Note: "YES" is case sensitive
    3. If YES is entered, all snapshots gets deleted.
