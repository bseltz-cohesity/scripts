### usage: ./viewDRclone.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -viewName 'My View' [ -newName 'Cloned-View' ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$viewName,
    [Parameter()][string]$viewList,
    [Parameter()][string]$policyName = $null,
    [Parameter(Mandatory = $True)][string]$inPath
)

# gather view list
if($viewList){
    $views = get-content $viewList
}elseif($viewName){
    $views = @($viewName)
}else{
    Write-Host "No Views Specified" -ForegroundColor Yellow
    exit
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### cluster info
$clusterName = (api get cluster).name

### policy info
if($policyName){
    # protect cloned view
    $policy = api get protectionPolicies | Where-Object name -eq $policyName
    if(!$policy){
        write-host "Policy $policyName not found!" -ForegroundColor Yellow
        exit
    }
}

foreach($viewName in $views){
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
    $viewResults = $searchResults.vms | Where-Object { $_.vmDocument.objectName -ieq $viewName }
    $viewResult = ($viewResults | Sort-Object -Property {$_.vmDocument.versions[0].snapshotTimestampUsecs} -Descending)[0]

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
            "Cloned $viewName"
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
                    $null = api post viewAliases @{'viewName' = $viewName; 'viewPath' = $viewPath; 'aliasName' = $alias.aliasName}
                }
            }
            if($policyName){
                # protect cloned view
                $protectionJob = @{
                    'name' = "$clusterName $($newView.name) backup";
                    'environment' = 'kView';
                    'viewBoxId' = $newView.viewBoxId;
                    'sourceIds' = @();
                    'excludeSourceIds' = @();
                    'vmTagIds' = @();
                    'excludeVmTagIds' = @();
                    'policyId' = $policy.id;
                    'priority' = 'kMedium';
                    'alertingPolicy' = @(
                        'kFailure'
                    );
                    'timezone' = 'America/New_York';
                    'incrementalProtectionSlaTimeMins' = 60;
                    'fullProtectionSlaTimeMins' = 120;
                    'qosType' = 'kBackupHDD';
                    'viewName' = $newView.name;
                    'isActive' = $true;
                    'sourceSpecialParameters' = @();
                    'indexingPolicy' = @{
                        'disableIndexing' = $true
                    };
                    'startTime' = @{
                        'hour' = 23;
                        'minute' = 55;
                    }
                }
                "Creating Protection Job for $($newView.name)..."
                $null = api post protectionJobs $protectionJob
            }
        }
    }else{
        write-host "View $viewName Not Found" -ForegroundColor Yellow
    }
}
