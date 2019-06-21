# Search for Files using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This powershell script searches for files with the specified file extension

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Begin download commands
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/findFiles/findFiles.ps1).content | Out-File findFiles.ps1; (Get-Content findFiles.ps1) | Set-Content findFiles.ps1
(Invoke-WebRequest -Uri https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell/findFiles/cohesity-api.ps1).content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End download commands
```

## Components

* findFiles.ps1: the main powershell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place both files in a folder together and run the main script like so:

```powershell
./findFiles.ps1 -vip mycluster -username myusername -domain mydomain.net -extension gif
```

```text
Found 25 results

Server   Path
------   ----
vCenter6 lvol_1/opt/vmware/lib/python2.7/email/test/data/PyBanner048.gif
vCenter6 lvol_1/opt/vmware/lib/python2.7/idlelib/Icons/folder.gif
vCenter6 lvol_1/opt/vmware/lib/python2.7/idlelib/Icons/idle_16.gif
vCenter6 lvol_1/opt/vmware/lib/python2.7/idlelib/Icons/idle_32.gif
vCenter6 lvol_1/opt/vmware/lib/python2.7/idlelib/Icons/idle_48.gif
vCenter6 lvol_1/opt/vmware/lib/python2.7/idlelib/Icons/minusnode.gif
vCenter6 lvol_1/opt/vmware/lib/python2.7/idlelib/Icons/openfolder.gif
vCenter6 lvol_1/opt/vmware/lib/python2.7/idlelib/Icons/plusnode.gif
vCenter6 lvol_1/opt/vmware/lib/python2.7/idlelib/Icons/python.gif
vCenter6 lvol_1/opt/vmware/lib/python2.7/idlelib/Icons/tk.gif
vCenter6 lvol_1/opt/vmware/lib/python2.7/test/imghdrdata/python.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/css/img/leftArrow.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/css/img/rightArrow.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/indeterminate.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/leftArrow.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/loader-spinner.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/loading_2x.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/loading-image.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/loading.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/Marge-anim-progressbar.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/rightArrow.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/slider-h.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/slider-v.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/img/whiteSpinner.gif
vCenter6 lvol_1/opt/vmware/share/htdocs/libs/img/loader-spinner.gif
```

## Parameters

* -vip: Cohesity cluster to connect to
* -username: Cohesity username
* -domain: (optional) Active Directory domain (defaults to 'local')
* -extension: last few characters of the file extention you are looking for

