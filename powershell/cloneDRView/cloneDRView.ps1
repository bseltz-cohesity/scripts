### usage: ./cloneDRView.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -viewName 'My View' -newName 'Cloned-View'

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter(Mandatory = $True)][string]$newName,
    [Parameter()][ValidateSet(“TestAndDev High”,”TestAndDev Low”,”Backup Target High”,"Backup Target Low","Backup Target SSD")][string]$qosPolicy = 'TestAndDev High',
    [Parameter()][hashtable[]]$whiteList = $null
)

### validate whitelist
if($whiteList){
    $validWhiteListKeys = @('ip', 'netmaskIp4', 'description')
    foreach($entry in $whiteList){
        foreach ($key in $entry.keys){
            if($key -notin $validWhiteListKeys){
                Write-Warning "Bad Whitelist Entry"
                exit
            }
        }
        if('ip' -notin $entry.keys -or 'netmaskIp4' -notin $entry.keys){
            Write-Warning "Bad WhiteList Entry"
            exit
        }
    }
}

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
        }
    }

    $cloneOp = api post /clone $cloneTask

    if ($cloneOp) {
        "Cloned $newName from $viewName"
        sleep 1
        $newView = (api get views).views | Where-Object { $_.name -eq $newName }
        $newView.enableSmbViewDiscovery = $true
        $newView.qos = @{
            "principalName" = $qosPolicy;
        }
        if ($newView.PSObject.Properties['logicalQuota']){
            $newView.logicalQuota | delApiProperty HardLimit
            $newView.logicalQuota | delApiProperty AlertLimit
            $newView.logicalQuota | delApiProperty alertThresholdPercentage
        }
        if($whiteList){
            if(! $newView.PSObject.Properties['subnetWhiteList']){
                $newView | Add-Member -MemberType NoteProperty -Name subnetWhiteList -Value @()
            }
            $newView.subnetWhitelist = $whiteList
        }
        $null = api put views $newView
    }
}else{
    write-host "View $viewName Not Found" -ForegroundColor Yellow
}
