# Maintain 30 Daily Clones of a View using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script clones a View from 30 previous daily backups (or less if 30 days worth of backups are unavailable). The script will also delete a cloned view that is 31 days old.

For example, if today is Aug 16 2018, and you you specify the view name SMBShare, the resulting views that are created will be:

```
SMBShare-2018-08-15
SMBShare-2018-08-14
SMBShare-2018-08-13
...
SMBShare-2018-07-17
```

If you run the script again the following day, SMBShare-2018-08-16 will be created, and SMBShare-2018-07-17 will be deleted.

Note: If there is no backup for a given day, a view for that day will not be created.

## Components

* cloneView30versions.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./cloneView30Versions.ps1 -vip mycluster -username admin [ -domain local ] -viewName SMBShare
```


