# Expunge VM Backups with PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

## Warning! This script deletes backup data! Make sure you know what you are doing before you run it

This powershell script searches for a VM, and deletes all backups of that VM, including the local snapshots, remote replicas and archives.

If you run the script without the -delete switch, the script will only display what it would delete. Use the -delete switch to actually perform the deletions.

Deletions will be logged to scriptPath/expungeVM.txt

## Components

* expungeVM.ps1: the main powershell script
* cohesityCluster.ps1: Cohesity REST API helper module

Place both files in a folder together, then we can run the script.

```powershell
./expungeVM.ps1 -vip mycluster -username myusername -domain mydomain.net -vmName myvm
```

First, run the script WITHOUT the -delete switch to see what would be deleted.

```powershell
powershell> ./expungeVM.ps1 -vip 192.168.1.199 -username admin -vmName deploy2
- Started at 03/28/2019 10:16:54 -------

--------------------------
    *TEST RUN MODE*  
    - not deleting
    - not logging
--------------------------

Connecting to local cluster 192.168.1.199...
Connecting to remote cluster BSeltzVE01...

Searching for deploy2...

  on CohesityVE...
  on BSeltzVE01...

Found the VM in the following protection runs:

    0: Deploy2 from VE2toGarrison: 3/27/19 10:00:00 PM
    1: Deploy2 from VE2toGarrison: 3/26/19 10:00:00 PM
    2: Deploy2 from VE2toGarrison: 3/25/19 10:00:01 PM
    3: Deploy2 from VE2toGarrison: 3/24/19 10:00:01 PM
    4: Deploy2 from VE2toGarrison: 3/23/19 10:00:01 PM

End state of protection runs:

  (Retained) 0: Deploy2 from VE2toGarrison: 3/27/19 10:00:00 PM
  (Retained) 1: Deploy2 from VE2toGarrison: 3/26/19 10:00:00 PM
  (Retained) 2: Deploy2 from VE2toGarrison: 3/25/19 10:00:01 PM
  (Retained) 3: Deploy2 from VE2toGarrison: 3/24/19 10:00:01 PM
  (Retained) 4: Deploy2 from VE2toGarrison: 3/23/19 10:00:01 PM

- Ended at 03/28/2019 10:16:56 -------
```

When you are happy for the script to actually delete what was displayed, rerun the command with the -delete switch

```powershell
powershell> ./expungeVM.ps1 -vip 192.168.1.199 -username admin -vmName deploy2 -delete
- Started at 03/28/2019 10:17:02 -------

----------------------------------
  *PERMANENT DELETE MODE*
  - selection will be deleted!!!
  - logging to /Users/brianseltzer/scripts/powershell/expungeVMLog-3-28-19_10-17-02_AM.txt
  - press CTRL-C to exit
----------------------------------

Connecting to local cluster 192.168.1.199...
Connecting to remote cluster BSeltzVE01...

Searching for deploy2...

  on CohesityVE...
  on BSeltzVE01...

Found the VM in the following protection runs:

    0: Deploy2 from VE2toGarrison: 3/27/19 10:00:00 PM
    1: Deploy2 from VE2toGarrison: 3/26/19 10:00:00 PM
    2: Deploy2 from VE2toGarrison: 3/25/19 10:00:01 PM
    3: Deploy2 from VE2toGarrison: 3/24/19 10:00:01 PM
    4: Deploy2 from VE2toGarrison: 3/23/19 10:00:01 PM

Deleting backups...

  Deleting 0: Deploy2 from VE2toGarrison: 3/27/19 10:00:00 PM
                        from BSeltzVE01
  Deleting 1: Deploy2 from VE2toGarrison: 3/26/19 10:00:00 PM
                        from BSeltzVE01
  Deleting 2: Deploy2 from VE2toGarrison: 3/25/19 10:00:01 PM
                        from BSeltzVE01
  Deleting 3: Deploy2 from VE2toGarrison: 3/24/19 10:00:01 PM
                        from BSeltzVE01
  Deleting 4: Deploy2 from VE2toGarrison: 3/23/19 10:00:01 PM
                        from BSeltzVE01

End state of protection runs:

  (Deleted)  0: Deploy2 from VE2toGarrison: 3/27/19 10:00:00 PM
  (Deleted)  1: Deploy2 from VE2toGarrison: 3/26/19 10:00:00 PM
  (Deleted)  2: Deploy2 from VE2toGarrison: 3/25/19 10:00:01 PM
  (Deleted)  3: Deploy2 from VE2toGarrison: 3/24/19 10:00:01 PM
  (Deleted)  4: Deploy2 from VE2toGarrison: 3/23/19 10:00:01 PM

- Ended at 03/28/2019 10:17:04 -------
```

Please note that there may be some delay before the deletions are reflected in subsequent VM search results.

## Download the Script

Run these commands from PowerShell to download the script(s) into your current directory:

```powershell
# download the scripts
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/expungeVM/expungeVM.ps1).content | Out-File expungeVM.ps1; (Get-Content expungeVM.ps1) | Set-Content expungeVM.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/expungeVM/cohesityCluster.ps1).content | Out-File cohesityCluster.ps1; (Get-Content cohesityCluster.ps1) | Set-Content cohesityCluster.ps1
#
```