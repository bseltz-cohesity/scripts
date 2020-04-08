### usage: ./cloneViewXVersions.ps1 -vip mycluster -username myusername -domain mydomain.net -viewName myview

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter()][int]$days = 7
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### search for view to clone
$searchResults = api get /searchvms?entityTypes=kView`&vmName=$viewName
$viewResult = $searchResults.vms | Where-Object { $_.vmDocument.objectName -ieq $viewName }

if ($viewResult) {
    
    $view = api get views/$($viewResult.vmDocument.objectName)?includeInactive=True
    $views = $(api get views).views

    $versions = $viewResult.vmDocument.versions

    $today = Get-Date

    1..$days | ForEach-Object {
        $thisDay = $today.AddDays(-$_)
        $thisDayUsecs = dateToUsecs $thisDay
        $nextDay = $today.AddDays(-$_+1)
        $nexDayUsecs = dateToUsecs $nextDay
        $year = $thisDay.Year
        $month = $thisDay.Month.ToString("00")
        $monthday = $thisDay.Day.ToString("00")
        $thisDayString = "$year-$month-$monthday"
        $thisDayVersions = $versions | Where-Object { ($_.instanceId.jobStartTimeUsecs -ge $thisDayUsecs) -and ($_.instanceId.jobStartTimeUsecs -le $nexDayUsecs) }
        if($thisDayVersions){
            # if view does not exist, create it
            $newName = "$viewName-$thisDayString"
            if(!($views | Where-Object {$_.name -ieq $newName})){
                $cloneTask = @{
                    "name"       = "Clone-View_" + $((get-date).ToString().Replace('/', '_').Replace(':', '_').Replace(' ', '_'));
                    "objects"    = @(
                        @{
                            "jobUid"         = $viewResult.vmDocument.objectId.jobUid;
                            "jobId"          = $viewResult.vmDocument.objectId.jobId;
                            "jobInstanceId"  = $thisDayVersions[-1].instanceId.jobInstanceId;
                            "startTimeUsecs" = $thisDayVersions[-1].instanceId.jobStartTimeUsecs;
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
            }else{
                "View $newName already exists"
            }   
        }else{
            "No view backup from $($thisDay.ToString('yyyy-MM-dd'))"
        }
    }
    # delete old view
    $oldDay = $today.AddDays(-$days-1)
    $year = $oldDay.Year
    $month = $oldDay.Month.ToString("00")
    $monthday = $oldDay.Day.ToString("00")
    $oldDayString = "$year-$month-$monthday"
    $oldName = "$viewName-$oldDayString"
    if($views | Where-Object {$_.name -ieq $oldName}){
        "Deleting view $oldName..."
        api delete views/$oldName
    }else{
        "Nothing old to delete"
    }
} else {
    write-host "View $viewName Not Found" -ForegroundColor Yellow
}
