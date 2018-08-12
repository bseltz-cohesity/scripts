### usage: ./cloneView.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -viewName 'SMBShare' -newName 'Cloned-SMBShare'

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter(Mandatory = $True)][string]$newName
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### search for view to clone
$searchResults = api get /searchvms?entityTypes=kView`&vmName=$viewName
$viewResult = $searchResults.vms | Where-Object { $_.vmDocument.objectName -ieq $viewName }

if ($viewResult) {
    
    $view = api get views/$($viewResult.vmDocument.objectName)?includeInactive=True

    $cloneTask = @{
        "name"       = "Clone-View_" + $((get-date).ToString().Replace('/', '_').Replace(':', '_').Replace(' ', '_'));
        "objects"    = @(
            @{
                "jobUid"         = $viewResult.vmDocument.objectId.jobUid;
                "jobId"          = $viewResult.vmDocument.objectId.jobId;
                "jobInstanceId"  = $viewResult.vmDocument.versions[0].instanceId.jobInstanceId;
                "startTimeUsecs" = $viewResult.vmDocument.versions[0].instanceId.jobStartTimeUsecs;
                "entity"         = $viewResult.vmDocument.objectId.entity; 
            }
        )
        "viewName"   = $newName;
        "action"     = 5;
        "viewParams" = @{
            "sourceViewName"        = $view.name;
            "cloneViewName"         = $newName;
            "viewBoxId"             = $view.viewBoxId;
            "viewId"                = $viewResult.vmDocument.objectId.entity.id;
            "qos"                   = $view.qos;
            "description"           = $view.description;
            "allowMountOnWindows"   = $view.allowMountOnWindows;
            "storagePolicyOverride" = $view.storagePolicyOverride;
        }

    }

    $cloneOp = api post /clone $cloneTask

    if ($cloneOp) {
        "Cloned $newName from $viewName"
    }

}
else {
    write-host "View $viewName Not Found" -ForegroundColor Yellow
}
