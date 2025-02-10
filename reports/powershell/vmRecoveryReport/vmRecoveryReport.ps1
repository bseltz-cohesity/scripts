# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][int]$daysBack = 7,
    [Parameter()][array]$taskName,
    [Parameter()][string]$taskList,
    [Parameter()][string]$outfileName = 'vmRecoveryReport.csv'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$taskNames = @(gatherList -Param $taskName -FilePath $taskList -Name 'jobs' -Required $false)

$nowUsecs = dateToUsecs
$midnight = Get-Date -Hour 0 -Minute 0
$midnightUsecs = dateToUsecs $midnight
$tonightUsecs = $midnightUsecs + 86399000000
$beforeUsecs = $midnightUsecs - ($daysBack * 86400000000) + 86400000000

$cluster = api get cluster

"""Cluster"",""Recovery Task Name"",""Recovery Task ID"",""Recovery Task Start Time"",""Recovery Type"",""Source VM Name"",""Target VM Name"",""VM Logical Size (GiB)"",""VM Used Size (GiB)"",""VM Status"",""Recovery Point"",""VM Start Time"",""VM End Time"",""VM Recovery Duration (Sec)"",""VM Percent"",""Instant Recovery Start Time"",""Instant Recovery End Time"",""Instant Recovery Duration (Sec)"",""Instant Recovery Percent"",""Datastore Migration Start Time"",""Datastore Migration End Time"",""Datastore Migration Duration (Sec)"",""Datastore Migration Percent""" | Out-File -FilePath $outfileName

$recoveries = api get -v2 "data-protect/recoveries?startTimeUsecs=$($beforeUsecs)&recoveryActions=RecoverVMs&includeTenants=true&endTimeUsecs=$($tonightUsecs)"

# catch invalid task names
if($taskNames.Count -gt 0){
    $notFoundTasks = $taskNames | Where-Object {$_ -notin $recoveries.recoveries.name}
    if($notFoundTasks){
        Write-Host ''
        foreach($notFoundTask in $notFoundTasks){
            Write-Host "Task $notFoundTask not found" -ForegroundColor Yellow
        }
    }
    $recoveries.recoveries = $recoveries.recoveries | Where-Object {$_.name -in $taskNames}
}

if($recoveries.recoveries.Count -eq 0){
    Write-Host "`nNo recoveries found`n"
    exit
}

foreach($recovery in $recoveries.recoveries){
    $thisRecovery = api get -v2 "data-protect/recoveries/$($recovery.id)?includeTenants=true"
    Write-Host $thisRecovery.name
    $recoveryStart = usecsToDate $thisRecovery.startTimeUsecs
    $recoveryStatus = $thisRecovery.status
    $recoveryType = $thisRecovery.vmwareParams.recoverVmParams.vmwareTargetParams.recoveryProcessType
    foreach($object in $thisRecovery.vmwareParams.objects){
        $objectStatus = $object.status
        $objectStart = $object.startTimeUsecs
        $objectRecoveryPoint = usecsToDate $object.snapshotCreationTimeUsecs
        $objectEnd = ''
        if($object.PSObject.Properties['endTimeUsecs'] -and $object.endTimeUsecs -ne $null -and $object.endTimeUsecs -gt 0){
            $objectEnd = $object.endTimeUsecs
            $objectDuration = [math]::Round(($objectEnd - $objectStart)/1000000, 0)
            $objectEnd = usecsToDate $objectEnd
            $objectPct = 100
        }else{
            $objectEnd = ''
            $objectDuration = [math]::Round(($nowUsecs - $objectStart)/1000000, 0)
            $progress = api get "/progressMonitors?taskPathVec=$($object.progressTaskId)&excludeSubTasks=true&includeFinishedTasks=true&includeEventLogs=false&fetchLogsMaxLevel=0"
            try{
                $objectPct = $progress.resultGroupVec[0].taskVec[0].progress.percentFinished
            }catch{
                $objectPct = 0
            }
        }
            
        $objectStart = usecsToDate $objectStart
        $objectName = $object.objectInfo.name
        $targetName = $objectName
        if($thisRecovery.vmwareParams.recoverVmParams.vmwareTargetParams.PSObject.Properties['renameRecoveredVmsParams']){
            $renameParams = $thisRecovery.vmwareParams.recoverVmParams.vmwareTargetParams.renameRecoveredVmsParams
            if($renameParams.PSObject.Properties['prefix']){
                $targetName = "{0}{1}" -f $renameParams.prefix, $targetName
            }
            if($renameParams.PSObject.Properties['suffix']){
                $targetName = "{0}{1}" -f $targetName, $renameParams.suffix
            }
        }
        try{
            $search = api get "/searchvms?entityIds=$($object.objectInfo.id)"
            $logicalSize = [math]::Round($search.vms[0].vmDocument.versions[0].logicalSizeBytes/(1024*1024*1024), 1)
            $size = [math]::Round($search.vms[0].vmDocument.objectId.entity.vmwareEntity.frontEndSizeInfo.sizeBytes/(1024*1024*1024), 1)
            if($size -gt $logicalSize){
                $size = $logicalSize
            }
        }catch{
            $size = ''
        }
        $instantDuration = ''
        $instantStart = ''
        $instantEnd = ''
        $instantPct = ''
        $migrateDuration = ''
        $migrateStart = ''
        $migrateEnd = ''
        $migratePct = ''
        if($recoveryType -eq 'InstantRecovery'){
            $instantInfo = $object.instantRecoveryInfo
            $instantStatus = $instantInfo.status
            $instantStart = $instantInfo.startTimeUsecs
            if($instantInfo.PSObject.Properties['endTimeUsecs'] -and $instantInfo.endTimeUsecs -ne $null -and $instantInfo.endTimeUsecs -gt 0){
                $instantEnd = $instantInfo.endTimeUsecs
                $instantDuration = [math]::Round(($instantEnd - $instantStart)/1000000, 0)
                $instantPct = 100
                $instantEnd = usecsToDate $instantEnd
            }else{
                $instantDuration = [math]::Round(($nowUsecs - $instantStart)/1000000, 0)
                $progress = api get "/progressMonitors?taskPathVec=$($instantInfo.progressTaskId)&excludeSubTasks=True&includeFinishedTasks=true&includeEventLogs=false&fetchLogsMaxLevel=0"
                try{
                    $instantPct = $progress.resultGroupVec[0].taskVec[0].progress.percentFinished
                }catch{
                    $instantPct = 0
                }
            }
            $instantStart = usecsToDate $instantStart
            $migrateInfo = $object.datastoreMigrationInfo
            $migrateStatus = $migrateInfo.status
            $migrateStart = $migrateInfo.startTimeUsecs
            if($migrateInfo.PSObject.Properties['endTimeUsecs'] -and $migrateInfo.endTimeUsecs -ne $null -and $migrateInfo.endTimeUsecs -gt 0){
                $migrateEnd = $migrateInfo.endTimeUsecs
                $migrateDuration = [math]::Round(($migrateEnd - $migrateStart)/1000000, 0)
                $migratePct = 100
                $migrateEnd = usecsToDate $migrateEnd
            }else{
                $migrateDuration = [math]::Round(($nowUsecs - $migrateStart)/1000000, 0)
                $progress = api get "/progressMonitors?taskPathVec=$($migrateInfo.progressTaskId)&excludeSubTasks=True&includeFinishedTasks=true&includeEventLogs=false&fetchLogsMaxLevel=0"
                try{
                    $migratePct = $progress.resultGroupVec[0].taskVec[0].progress.percentFinished
                }catch{
                    $migratePct = 0
                }
            }
            $migrateStart = usecsToDate $migrateStart
        }
        Write-Host "    $objectName $objectStatus $($objectPct)%"
        """{0}"",""{1}"",""{2}"",""{3}"",""{4}"",""{5}"",""{6}"",""{7}"",""{8}"",""{9}"",""{10}"",""{11}"",""{12}"",""{13}"",""{14}"",""{15}"",""{16}"",""{17}"",""{18}"",""{19}"",""{20}"",""{21}"",""{22}""" -f $cluster.name, $thisRecovery.name, $thisRecovery.id, $recoveryStart, $recoveryType, $objectName, $targetName, $logicalSize, $size, $objectStatus, $objectRecoveryPoint, $objectStart, $objectEnd, $objectDuration, $objectPct, $instantStart, $instantEnd, $instantDuration, $instantPct, $migrateStart, $migrateEnd, $migrateDuration, $migratePct | Out-File -FilePath $outfileName -Append
    }
}

Write-Host "`nOutput saved to $outfileName`n"
