### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][ValidateSet('sql','view','vm','oracle', 'appview')][string]$type,
    [Parameter()][string]$source,
    [Parameter()][string]$sourceDB,
    [Parameter()][string]$target,
    [Parameter()][string]$targetDB,
    [Parameter()][string]$taskId,
    [Parameter()][string]$olderThan = 0,
    [Parameter()][switch]$destroy,
    [Parameter()][switch]$wait
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

$views = api get views

$olderThanUsecs = dateToUsecs ((Get-Date).AddDays(-$olderThan))

$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfile = "cloneList-$($cluster.name)-$dateString.csv"
"TaskId,Created,Type,Source,Target" | Out-File -FilePath $outfile

$cloneTypes = @{ 'vm' = 2; 'view' = 5; 'sql' = 7 ; 'oracle' = 7; 'appview' = 18}

### get list of active clones
$clones = api get ("/restoretasks?restoreTypes=kCloneView&restoreTypes=kCloneApp&restoreTypes=kCloneVMs&restoreTypes=kCloneAppView") `
    | where-object { $_.restoreTask.destroyClonedTaskStateVec -eq $null } `
    | Where-Object { $_.restoreTask.performRestoreTaskState.base.publicStatus -eq 'kSuccess' } `
    | Where-Object {$_.restoreTask.performRestoreTaskState.base.startTimeUsecs -le $olderThanUsecs}

foreach ($clone in $clones){

    $cloneType = $clone.restoreTask.performRestoreTaskState.base.type
    $thisTaskId = $clone.restoreTask.performRestoreTaskState.base.taskId
    $startTimeUsecs = $clone.restoreTask.performRestoreTaskState.base.startTimeUsecs
    $typeMatch = !$type -or $cloneTypes[$type] -eq $cloneType

    if($cloneType -eq 7 -and $typeMatch){  # databases

        $targetHost = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.targetHost.displayName
        $sourceHost = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.ownerRestoreInfo.ownerObject.entity.displayName
        $sourceDBName = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].appEntity.displayName 
        
        # MSSQL
        if($clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.type -eq 3){
            $cloneTypeName = 'SQL'
            if($type -and $type -ne 'sql'){
                $typeMatch = $false
            }

            $targetDBName = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.newDatabaseName
            $targetInstance = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.instanceName
            $targetDBName = "$targetInstance/$targetDBName"

            $targetServerMatch = !$target -or ($target -eq $targetHost)
            $targetDBMatch = !$targetDB -or ($targetDB -eq $targetDBName)
            $sourceServerMatch = !$source -or ($source -eq $sourceHost)
            $sourceDBMatch = !$sourceDB -or ($sourceDB -eq $sourceDBName)
            $taskIdMatch = !$taskId -or $taskId -eq $thisTaskId

            if($sourceServerMatch -and $targetServerMatch -and $sourceDBMatch -and $targetDBMatch -and $taskIdMatch -and $typeMatch){

                "`n{0} ({1}): `n    [{2}] {3}/{4} -> {5}/{6}" -f  $thisTaskId,
                    (usecsToDate $startTimeUsecs),
                    $cloneTypeName,
                    $sourceHost,
                    $sourceDBName,
                    $targetHost,
                    $targetDBName

                "{0},{1},{2},{3}/{4},{5}/{6}" -f $thisTaskId,
                    (usecsToDate $startTimeUsecs),
                    $cloneTypeName,
                    $sourceHost,
                    $sourceDBName,
                    $targetHost,
                    $targetDBName | Out-File -FilePath $outfile -Append

                if($destroy){
                    $restoreTask = api post "/destroyclone/$thisTaskId"
                    if($wait){
                        while($restoreTask.restoreTask.destroyClonedTaskStateVec[0].status -eq 1){
                            Start-Sleep 5
                            $restoreTask = api get "/restoretasks/$taskId"
                        }
                    }
                    Write-Host "Clone Destroyed"
                }
            }
        }

        # Oracle
        if($clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.type -eq 19){
            $cloneTypeName = 'Oracle'
            if($type -and $type -ne 'oracle'){
                $typeMatch = $false
            }

            $targetDBName = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.newDatabaseName

            $targetServerMatch = !$target -or ($target -eq $targetHost)
            $targetDBMatch = !$targetDB -or ($targetDB -eq $targetDBName)
            $sourceServerMatch = !$source -or ($source -eq $sourceHost)
            $sourceDBMatch = !$sourceDB -or ($sourceDB -eq $sourceDBName)
            $taskIdMatch = !$taskId -or $taskId -eq $thisTaskId

            if($sourceServerMatch -and $targetServerMatch -and $sourceDBMatch -and $targetDBMatch -and $taskIdMatch -and $typeMatch){

                "`n{0} ({1}): `n    [{2}] {3}/{4} -> {5}/{6}" -f  $thisTaskId,
                    (usecsToDate $startTimeUsecs),
                    $cloneTypeName,
                    $sourceHost,
                    $sourceDBName,
                    $targetHost,
                    $targetDBName

                "{0},{1},{2},{3}/{4},{5}/{6}" -f  $thisTaskId,
                    (usecsToDate $startTimeUsecs),
                    $cloneTypeName,
                    $sourceHost,
                    $sourceDBName,
                    $targetHost,
                    $targetDBName | Out-File -FilePath $outfile -Append

                if($destroy){
                    $restoreTask = api post "/destroyclone/$thisTaskId"
                    if($wait){
                        while($restoreTask.restoreTask.destroyClonedTaskStateVec[0].status -eq 1){
                            Start-Sleep 5
                            $restoreTask = api get "/restoretasks/$taskId"
                        }
                    }
                    Write-Host "Clone Destroyed"
                }
            }
        }
    }

    # Oracle View
    if($cloneType -eq 18){
        $targetHost = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.targetHost.displayName
        $sourceHost = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.ownerRestoreInfo.ownerObject.entity.displayName
        $sourceDBName = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].appEntity.displayName 
        
        $cloneTypeName = 'App View'
        if($type -and $type -ne 'appview'){
            $typeMatch = $false
        }

        $targetDBName = $clone.restoreTask.performRestoreTaskState.fullViewName
        # $targetDBName = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.newDatabaseName
        
        $targetServerMatch = !$target -or ($target -eq $targetHost)
        $targetDBMatch = !$targetDB -or ($targetDB -eq $targetDBName)
        $sourceServerMatch = !$source -or ($source -eq $sourceHost)
        $sourceDBMatch = !$sourceDB -or ($sourceDB -eq $sourceDBName)
        $taskIdMatch = !$taskId -or $taskId -eq $thisTaskId

        if($sourceServerMatch -and $targetServerMatch -and $sourceDBMatch -and $targetDBMatch -and $taskIdMatch -and $typeMatch){

            "`n{0} ({1}): `n    [{2}] {3}/{4} -> {5}/{6}" -f  $thisTaskId,
                (usecsToDate $startTimeUsecs),
                $cloneTypeName,
                $sourceHost,
                $sourceDBName,
                $targetHost,
                $targetDBName

            "{0},{1},{2},{3}/{4},{5}/{6}" -f  $thisTaskId,
                (usecsToDate $startTimeUsecs),
                $cloneTypeName,
                $sourceHost,
                $sourceDBName,
                $targetHost,
                $targetDBName | Out-File -FilePath $outfile -Append

            if($destroy){
                $restoreTask = api post "/destroyclone/$thisTaskId"
                if($wait){
                    while($restoreTask.restoreTask.destroyClonedTaskStateVec[0].status -eq 1){
                        Start-Sleep 5
                        $restoreTask = api get "/restoretasks/$taskId"
                    }
                }
                Write-Host "Clone Destroyed"
            }
        }
    }

    # VMs
    if($cloneType -eq 2 -and $typeMatch){
        if($sourceDB -or $targetDB){
            continue
        }
        $cloneTypeName = 'VM'
        $canDestroy = $false

        foreach ($vm in $clone.restoreTask.performRestoreTaskState.restoreInfo.restoreEntityVec){

            $sourceVMName = $vm.entity.displayName
            $targetVMName = $vm.restoredEntity.vmwareEntity.name

            $sourceVMMatch = !$source -or ($source -eq $sourceVMName)
            $targetVMMatch = !$target -or ($target -eq $targetVMName)
            $taskIdMatch = !$taskId -or ($taskId -eq $thisTaskId)

            if($sourceVMMatch -and $targetVMMatch -and $taskIdMatch -and $typeMatch){

                "`n{0} ({1}): `n    [{2}] {3} -> {4}" -f  $thisTaskId,
                    (usecsToDate $startTimeUsecs),
                    $cloneTypeName,
                    $sourceVMName,
                    $targetVMName

                "{0},{1},{2},{3},{4}" -f  $thisTaskId,
                    (usecsToDate $startTimeUsecs),
                    $cloneTypeName,
                    $sourceVMName,
                    $targetVMName | Out-File -FilePath $outfile -Append
                
                $canDestroy = $True
            }
        }

        if($canDestroy -and $destroy){
            $restoreTask = api post "/destroyclone/$thisTaskId"
            if($wait){
                while($restoreTask.restoreTask.destroyClonedTaskStateVec[0].status -eq 1){
                    Start-Sleep 5
                    $restoreTask = api get "/restoretasks/$taskId"
                }
            }
            Write-Host "Clone Destroyed"
        }
    }

    # views
    if($cloneType -eq 5 -and $typeMatch){
        if($sourceDB -or $targetDB){
            continue
        }
        $cloneTypeName = 'View'

        $sourceViewName = $clone.restoreTask.performRestoreTaskState.objects[0].entity.displayName
        $targetViewName = $clone.restoreTask.performRestoreTaskState.fullViewName

        $sourceViewMatch = !$source -or ($source -eq $sourceViewName)
        $targetViewMatch = !$target -or ($target -eq $targetViewName)
        $taskIdMatch = !$taskId -or $taskId -eq $thisTaskId

        $viewStillExists = ($views.views | Where-Object name -eq $targetViewName) -and ($sourceViewName -ne $targetViewName)
        if($viewStillExists -and $sourceViewMatch -and $targetViewMatch -and $taskIdMatch -and $typeMatch){

            "`n{0} ({1}): `n    [{2}] {3} -> {4}" -f $thisTaskId,
                (usecsToDate $startTimeUsecs),
                $cloneTypeName,
                $sourceViewName,
                $targetViewName

            "{0},{1},{2},{3},{4}" -f $thisTaskId,
                (usecsToDate $startTimeUsecs),
                $cloneTypeName,
                $sourceViewName,
                $targetViewName | Out-File -FilePath $outfile -Append

            if($destroy){
                $null = api delete "views/$targetViewName"
                Write-Host "Clone Destroyed"
            }
        }
    }
}
""
