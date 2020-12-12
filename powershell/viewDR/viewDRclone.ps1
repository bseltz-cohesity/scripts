### usage: ./viewDRclone.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -viewName 'My View' [ -newName 'Cloned-View' ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList,
    [Parameter()][switch]$all,
    [Parameter()][string]$policyName = $null,
    [Parameter(Mandatory = $True)][string]$inPath
)

# gather view list
if($viewList){
    $myViews = get-content $viewList
}elseif($viewNames){
    $myViews = @($viewNames)
}elseif($all){
    if(test-path $inPath){
        $files = Get-ChildItem $inPath
        $myViews = @()
        foreach($file in $files){
            $myViews += [string]$file.name
        }
    }else{
        Write-Warning "Can't access $inPath"
        exit
    }
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

### get view protection jobs
$jobs = api get protectionJobs?environments=kView

### policy info
if($policyName){
    # protect cloned view
    $policy = api get protectionPolicies | Where-Object name -eq $policyName
    if(!$policy){
        write-host "Policy $policyName not found!" -ForegroundColor Yellow
        exit
    }
}

if(! (Test-Path $inPath)){
    Write-Warning "$inPath not found"
    exit
}

function getViews(){
    $myViews = @()
    $views = api get "views?includeInactive=True"
    $myViews += $views.views
    $lastResult = $views.lastResult
    while(! $lastResult){
        $lastViewId = $views.views[-1].viewId
        $views = api get "views?maxViewId=$lastViewId&includeInactive=True"
        $lastResult = $views.lastResult
        $myViews += $views.views
    }
    return $myViews
}

"Gathering Views..."
$views = getViews

$clonedViewList = "clonedViews-{0}" -f (get-date).ToString('yyyy-MM-dd_hh-mm-ss')
$migratedShares = "migratedShares.txt"
$null = Remove-Item -Path $migratedShares -Force -ErrorAction SilentlyContinue

foreach($viewName in $myViews){
    $viewName = [string]$viewName
    ### get view metadata from file
    $filePath = Join-Path -Path $inPath -ChildPath $viewName
    if(Test-Path $filePath){
        $metadata = Get-Content $filePath | ConvertFrom-Json
    }else{
        Write-Host "$filePath not found" -ForegroundColor Yellow
        continue
    }

    ### search for view to clone
    $searchResults = api get /searchvms?entityTypes=kView`&vmName=$viewName
    $viewResults = $searchResults.vms | Where-Object { $_.vmDocument.objectName -ieq $viewName }
    if($viewResults){
        $viewResult = ($viewResults | Sort-Object -Property {$_.vmDocument.versions[0].snapshotTimestampUsecs} -Descending)[0]
    }else{
        Write-Host "$viewName not replicated to this cluster" -ForegroundColor Yellow
        $viewResult = $null
    }
    
    if ($viewResult) {
        $job = $jobs | Where-Object {$_.name -eq $viewResult.vmDocument.jobName}
        if($job.PSObject.Properties['remoteViewName']){
            $view = $views | Where-Object {$_.name -eq $job.remoteViewName}
        }else{
            $view = $views | Where-Object {$_.name -eq $viewResult.vmDocument.objectName}
        }
        $view = $view[0]
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
            "$viewName" | Out-File -FilePath $clonedViewList -Append
            "$viewName" | Out-File -FilePath $migratedShares -Append
        }
    }
}

Start-Sleep 3

$views = getViews

foreach($viewName in $myViews){
    $viewName = [string]$viewName
    $newView = ($views | Where-Object name -eq $viewName)
    if($newView){
        $newView = $newView[0]
        if($newView.PSObject.Properties['createTimeMsecs']){
            ### get view metadata from file
            $filePath = Join-Path -Path $inPath -ChildPath $viewName
            if(Test-Path $filePath){
                $metadata = Get-Content $filePath | ConvertFrom-Json
            }else{
                Write-Host "$filePath not found" -ForegroundColor Yellow
                continue
            }
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
                    "$($alias.aliasName)" | Out-File -FilePath $migratedShares -Append
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
    }
}
