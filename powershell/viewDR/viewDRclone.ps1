### usage: ./viewDRclone.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -viewName 'My View' [ -newName 'Cloned-View' ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter()][string]$newName = $viewName,
    [Parameter(Mandatory = $True)][string]$inPath
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get view metadata from file
$inPath = Join-Path -Path $inPath -ChildPath $viewName
if(Test-Path $inPath){
    $metadata = Get-Content $inPath | ConvertFrom-Json
}else{
    Write-Warning "$inPath not found"
    exit 
}

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
        Start-Sleep 1
        $newView = (api get views).views | Where-Object { $_.name -eq $newName }
        $newView.enableSmbViewDiscovery = $metadata.enableSmbViewDiscovery
        $newView.qos = @{
            "principalName" = $metadata.qos.principalName;
        }
        if($metadata.PSObject.Properties['subnetWhitelist']){
            if(! $newView.PSObject.Properties['subnetWhiteList']){
                $newView | Add-Member -MemberType NoteProperty -Name subnetWhiteList -Value @()
            }
            $newView.subnetWhitelist = $metadata.subnetWhiteList
        }
        $null = api put views $newView
        if($metadata.PSObject.Properties['aliases']){
            write-host "Creating Shares..."
            foreach($alias in $metadata.aliases){
                write-host "`t$($alias.aliasName)"
                $viewPath = $alias.viewPath.trimend("/")
                $null = api post viewAliases @{'viewName' = $newName; 'viewPath' = $viewPath; 'aliasName' = $alias.aliasName}
            }
        }
    }
}else{
    write-host "View $viewName Not Found" -ForegroundColor Yellow
}
