### usage: ./viewDRclone.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] -viewName 'My View' [ -newName 'Cloned-View' ] -inPath \\myserver\mypath

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][array]$viewNames,
    [Parameter()][string]$viewList,
    [Parameter()][string]$suffix,
    [Parameter()][string]$jobPrefix = 'failover',
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

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

### cluster info
$cluster = api get cluster
$clusterName = $cluster.name

### get view protection jobs
$jobs = api get protectionJobs?environments=kView
$protectionGroups = api get -v2 data-protect/protection-groups?environments=kView

### policy info
if($policyName){
    # protect cloned view
    $policy = api get protectionPolicies | Where-Object name -eq $policyName
    if(!$policy){
        write-host "Policy $policyName not found!" -ForegroundColor Yellow
        exit
    }
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
        continue
    }
    
    $doc = $viewResult.vmDocument
    $versions = $viewResult.vmDocument.versions
    $processView = $True
    $job = $jobs | Where-Object {$_.name -eq $viewResult.vmDocument.jobName}
    $job = $job[0]
    $version = $versions[0]
    if($snapshotDate){
        $snapshotUsecs = dateToUsecs $snapshotDate
        $versions = $viewResult.vmDocument.versions | Where-Object {$_.instanceId.jobStartTimeUsecs -le ($snapshotUsecs + 60000000)}
        if($versions.Count -gt 0){
            $version = $versions[0]
        }else{
            $processView = $false
            Write-Host "No backups for $viewName available from $snapshotDate" -ForegroundColor Yellow
            continue
        }
    }
    $cloneTask = @{
        "name"       = "Clone-View_" + $((get-date).ToString().Replace('/', '_').Replace(':', '_').Replace(' ', '_'));
        "objects"    = @(
            @{
                "jobUid"         = $doc.objectId.jobUid;
                "jobId"          = $doc.objectId.jobId;
                "jobInstanceId"  = $version.instanceId.jobInstanceId;
                "startTimeUsecs" = $version.instanceId.jobStartTimeUsecs;
                "entity"         = $doc.objectId.entity; 
            }
        )
        "viewName"   = "$($metadata.name)$suffix";
        "action"     = 5;
        "viewParams" = @{
            "sourceViewName"        = $doc.objectId.entity.displayName;
            "cloneViewName"         = "$($metadata.name)$suffix";
            "viewBoxId"             = $doc.viewBoxId;
            "viewId"                = $doc.objectId.entity.id;
        }
    }
    Write-Host "cloning $viewName"
    $cloneOp = api post /clone $cloneTask
    if ($cloneOp) {
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
                $job = $protectionGroups.protectionGroups | Where-Object {$_.name -eq $viewResult.vmDocument.jobName}
                $job = $job[0]
                $newJobName = "$($jobPrefix)-$($job.name)"
                $newJob = $protectionGroups.protectionGroups | Where-Object {$_.name -eq $newJobName}
                if(!$newJob){
                    $newJob = @{
                        "policyId" = $policy.id;
                        "startTime" = $job.startTime;
                        "priority" = "kMedium";
                        "sla" = $job.sla;
                        "abortInBlackouts" = $job.abortInBlackouts;
                        "storageDomainId" = $newView.viewBoxId;
                        "name" = $newJobName;
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
                    "Creating Protection Job $newJobName - adding $($newView.name)..."
                    $null = api post -v2 data-protect/protection-groups $newJob
                    Start-Sleep 2
                    $protectionGroups = api get -v2 data-protect/protection-groups?environments=kView
                }else{
                    $newJob.viewParams.objects = @($newJob.viewParams.objects + @{"id" = $newView.viewId})
                    $newJob.viewParams.replicationParams.viewNameConfigList = @($newJob.viewParams.replicationParams.viewNameConfigList + @{
                        "sourceViewId" = $newView.viewId;
                        "useSameViewName" = $false;
                        "viewName" = "$viewName-DR"
                    })
                    "Updating Protection Job $newJobName - adding $($newView.name)..."
                    $null = api put -v2 data-protect/protection-groups/$($newJob.id) $newJob
                    $protectionGroups = api get -v2 data-protect/protection-groups?environments=kView
                }
            }
        }
    }
    $null = api delete "views/$($viewName)-DR"
}
