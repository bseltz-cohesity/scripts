### usage: ./viewDRcloneAll.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$inPath
)

if(test-path $inPath){
    $files = Get-ChildItem $inPath
}else{
    Write-Warning "Can't access $inPath"
    exit
}

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain


function cloneView($viewName, $fileName){
    ### get view metadata from file
    $metadata = Get-Content $fileName | ConvertFrom-Json

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
            "viewName"   = $viewName;
            "action"     = 5;
            "viewParams" = @{
                "sourceViewName"        = $view.name;
                "cloneViewName"         = $viewName;
                "viewBoxId"             = $view.viewBoxId;
                "viewId"                = $viewResult.vmDocument.objectId.entity.id;
            }
        }

        $cloneOp = api post /clone $cloneTask

        if ($cloneOp) {
            "Recovering $viewName"
            Start-Sleep 1
            $newView = (api get views).views | Where-Object { $_.name -eq $viewName }
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
}

foreach($file in $files){
    $viewname = $file.name
    $filename = $file.FullName
    cloneView $viewname $filename
}
