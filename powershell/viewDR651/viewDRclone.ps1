### usage: ./viewDRclone.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -viewName 'My View' [ -newName 'Cloned-View' ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList,
    [Parameter()][string]$suffix,
    [Parameter()][switch]$all,
    [Parameter()][string]$policyName = $null,
    [Parameter(Mandatory = $True)][string]$inPath,
    [Parameter()][string]$snapshotDate = $null
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
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

### cluster info
$cluster = api get cluster
$clusterName = $cluster.name

### get view protection jobs
$jobs = api get protectionJobs?environments=kView
if($cluster.clusterSoftwareVersion -ge '6.6'){
    $protectionGroups = api get -v2 data-protect/protection-groups?environments=kView
}

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

"Gathering Views...`n"
$views = getViews

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
        $viewResult = ($viewResults | Sort-Object -Property {$_.vmDocument.versions[0].snapshotTimestampUsecs} -Descending:$True)[0]
    }else{
        Write-Host "$viewName not replicated to this cluster" -ForegroundColor Yellow
        $viewResult = $null
    }
    
    if ($viewResult) {
        $processView = $True
        $job = $jobs | Where-Object {$_.name -eq $viewResult.vmDocument.jobName}
        $job = $job[0]
        $view = $null
        if($job.PSObject.Properties['remoteViewName'] -and !$snapshotDate){
            $remoteViews = $views | Where-Object {$job.name -in $_.viewProtection.protectionJobs.jobName}
            $remoteView = ($remoteViews | Sort-Object -Property viewId -Descending)[0]
            $view = $remoteView
        }
        if($null -ne $view -and $view.PSObject.Properties['viewId'] -and !$snapshotDate){
            $cloneTask = @{
                "name"       = "Clone-View_" + $((get-date).ToString().Replace('/', '_').Replace(':', '_').Replace(' ', '_'));
                "objects"    = @(
                    @{
                        "entity" = @{
                            "type" = 4;
                            "viewEntity" = @{
                                "name" = $view.name;
                                "uid" = @{
                                    "clusterId" = $cluster.id;
                                    "clusterIncarnationId" = $cluster.incarnationId;
                                    "objectId" = $view.viewId
                                };
                                "type" = 1
                            }
                        }
                    }
                )
                "viewName"   = "$($metadata.name)$suffix";
                "action"     = 5;
                "viewParams" = @{
                    "sourceViewName"        = $view.name;
                    "cloneViewName"         = "$($metadata.name)$suffix";
                    "viewBoxId"             = $view.viewBoxId;
                    "viewId"                = $view.viewId;
                    "qos"                   = $view.qos;
                    "protocolAccess"        = $view.protocolAccess
                }
            }
            $version =  $viewResult.vmDocument.versions[0]
        }else{
            $version = $null
            if($snapshotDate){
                $snapshotUsecs = dateToUsecs $snapshotDate
                $versions = $viewResult.vmDocument.versions | Where-Object {$_.instanceId.jobStartTimeUsecs -le ($snapshotUsecs + 60000000)}
                if($versions.Count -gt 0){
                    $version = $versions[0]
                }else{
                    $processView = $false
                    Write-Host "No backups for $viewName available from $snapshotDate" -ForegroundColor Yellow
                }
            }else{
                $version = $viewResult.vmDocument.versions[0]
            }

            if($version){
                $view = $views | Where-Object {$_.name -eq $viewResult.vmDocument.objectName}
                $view = $view[0]
                $cloneTask = @{
                    "name"       = "Clone-View_" + $((get-date).ToString().Replace('/', '_').Replace(':', '_').Replace(' ', '_'));
                    "objects"    = @(
                        @{
                            "jobUid"         = $viewResult.vmDocument.objectId.jobUid;
                            "jobId"          = $viewResult.vmDocument.objectId.jobId;
                            "jobInstanceId"  = $version.instanceId.jobInstanceId;
                            "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
                            "entity"         = $viewResult.vmDocument.objectId.entity; 
                        }
                    )
                    "viewName"   = "$($metadata.name)$suffix";
                    "action"     = 5;
                    "viewParams" = @{
                        "sourceViewName"        = $view.name;
                        "cloneViewName"         = "$($metadata.name)$suffix";
                        "viewBoxId"             = $view.viewBoxId;
                        "viewId"                = $viewResult.vmDocument.objectId.entity.id;
                    }
                }
            }
        }
        if($processView){
            $cloneOp = api post /clone $cloneTask

            if ($cloneOp) {
                Write-Host "Cloning $viewName from $(usecsToDate $version.instanceId.jobStartTimeUsecs)"
                # "$viewName" | Out-File -FilePath $clonedViewList -Append
                "$viewName" | Out-File -FilePath $migratedShares -Append
                if($remoteViews){
                    foreach($oldView in $remoteViews){
                        if($oldView.name -ne "$viewName$suffix"){
                            $null = api delete "views/$($oldView.name)"
                        }
                    }
                    $remoteViews = $null
                }
            }
        }
    }
}

Start-Sleep 3

$views = getViews

foreach($viewName in $myViews){
    $viewName = [string]$viewName
    $newView = ($views | Where-Object name -eq "$viewName$suffix")
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
                write-host "`nCreating Shares..."
                foreach($alias in $metadata.aliases){
                    write-host "`t$($alias.aliasName)"
                    $viewPath = $alias.viewPath.trimend("/")
                    $null = api post viewAliases @{'viewName' = "$viewName$suffix"; 'viewPath' = $viewPath; 'aliasName' = $alias.aliasName; 'sharePermissions' = $alias.sharePermissions}
                    "$($alias.aliasName)" | Out-File -FilePath $migratedShares -Append
                }
            }
            if($policyName){
                # protect cloned view
                $searchResults = api get /searchvms?entityTypes=kView`&vmName=$viewName
                $viewResults = $searchResults.vms | Where-Object { $_.vmDocument.objectName -ieq $viewName }
                $viewResult = ($viewResults | Sort-Object -Property {$_.vmDocument.versions[0].snapshotTimestampUsecs} -Descending:$True)[0]
                if($cluster.clusterSoftwareVersion -lt '6.6'){
                    $job = $jobs | Where-Object {$_.name -eq $viewResult.vmDocument.jobName}
                    $job = $job[0]
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
                        'alertingPolicy' = $job.alertingPolicy;
                        'createRemoteView' = $True
                        'remoteViewName' = "$($viewName)-DR"
                        'timezone' = $job.timezone;
                        'incrementalProtectionSlaTimeMins' = $job.incrementalProtectionSlaTimeMins;
                        'fullProtectionSlaTimeMins' = $job.fullProtectionSlaTimeMins;
                        'qosType' = $job.qosType;
                        'viewName' = $newView.name;
                        'isActive' = $true;
                        'sourceSpecialParameters' = @();
                        'indexingPolicy' = $job.indexingPolicy;
                        'startTime' = $job.startTime
                    }
                    "Creating Protection Job for $($newView.name)..."
                    $null = api post protectionJobs $protectionJob
                }else{
                    $job = $protectionGroups.protectionGroups | Where-Object {$_.name -eq $viewResult.vmDocument.jobName}
                    $job = $job[0]
                    $protectionGroup = @{
                        "policyId" = $policy.id;
                        "startTime" = $job.startTime;
                        "priority" = "kMedium";
                        "sla" = $job.sla;
                        "abortInBlackouts" = $job.abortInBlackouts;
                        "storageDomainId" = $newView.viewBoxId;
                        "name" = "$clusterName $($newView.name) backup";
                        "environment" = "kView";
                        "isPaused" = $false;
                        "description" = "";
                        "alertPolicy" = $job.alertPolicy;
                        "viewParams" = @{
                            "indexingPolicy" = $job.viewParams.indexingPolicy;
                            "replicationParams" = @{
                                "viewNameConfigList" = @(
                                    @{
                                        "sourceViewId" = $newView.viewId;
                                        "useSameViewName" = $false;
                                        "viewName" = "$viewName-DR"
                                    }
                                )
                            };
                            "objects" = @(
                                @{
                                    "id" = $newView.viewId
                                }
                            );
                            "externallyTriggeredJobParams" = @{}
                        }
                    }
                    "Creating Protection Job for $($newView.name)..."
                    $null = api post -v2 data-protect/protection-groups $protectionGroup                    
                }
            }
        }
    }
}
