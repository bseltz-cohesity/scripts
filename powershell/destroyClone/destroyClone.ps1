
# usage: ./destroyClone.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -cloneType { sql | view | vm } [ -viewName myview ] [ -vmName myvm ] [ -dbName mydb ] [ -dbServer myDBserver ] [ -instance MSSQLSERVER ]

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
    [Parameter(Mandatory = $True)][ValidateSet('sql','view','vm','oracle','oracle_view','azure_vm')][string]$cloneType,
    [Parameter()][string]$viewName = '',  # name of clone view to tear down
    [Parameter()][string]$vmName = '',  # name of clone VM to tear down
    [Parameter()][array]$dbName,  # namea of clone DBs to tear down
    [Parameter()][string]$dbList,  # text file of db names to tear down
    [Parameter()][string]$dbServer = '',  # name of dbServer where clone is attached
    [Parameter()][string]$instance = 'MSSQLSERVER',
    [Parameter()][switch]$wait
)

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

$dbNames = @(gatherList -Param $dbName -FilePath $dbList -Name 'dbs' -Required $false)
$foundDBs = @()

if ($cloneType -eq 'sql' -or $cloneType -eq 'oracle'){
    if($dbNames.Count -eq 0 -or $dbServer -eq ''){
        write-host "dbName (or dbList) and dbServer parameters required" -foregroundcolor yellow
        exit
    }
}

if ($cloneType -eq 'view' -or $cloneType -eq 'oracle_view'){
    if($viewName -eq ''){
        write-host "viewName parameter required" -foregroundcolor yellow
        exit  
    }
}

if ($cloneType -eq 'vm' -or $cloneType -eq 'azure_vm'){
    if($vmName -eq ''){
        write-host "vmName parameter required" -foregroundcolor yellow
        exit  
    }
}

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

$cloneTypes = @{ 'vm' = 2; 'view' = 5; 'sql' = 7; 'oracle' = 7; 'oracle_view' = 18; 'azure_vm' = 9}

$taskId = $null

# get list of active clones
$clones = api get ("/restoretasks?restoreTypes=kCloneView&" +
                                "restoreTypes=kCloneApp&" +
                                "restoreTypes=kCloneVMs&" +
                                "restoreTypes=kConvertAndDeployVMs&" +
                                "restoreTypes=kCloneAppView") `
                                | where-object { $_.restoreTask.destroyClonedTaskStateVec -eq $null } `
                                | Where-Object { $_.restoreTask.performRestoreTaskState.base.type -eq $cloneTypes[$cloneType]} `
                                | Where-Object { $_.restoreTask.performRestoreTaskState.base.publicStatus -eq 'kSuccess' }


function teardown($taskId){
    $restoreTask = api post "/destroyclone/$taskId"
    if($wait){
        while($restoreTask.restoreTask.destroyClonedTaskStateVec[0].status -eq 1){
            Start-Sleep 5
            $restoreTask = api get "/restoretasks/$taskId"
        }
        Write-Host "Clone Destroyed"
    }
}

# find matching clone
foreach ($clone in $clones){

    $thisTaskId = $clone.restoreTask.performRestoreTaskState.base.taskId
    $thisClone = api get "/restoretasks/$thisTaskId"

    # tear down SQL clone
    if($cloneType -eq 'sql'){
        
        $cloneDB = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.newDatabaseName
        $cloneHost = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.targetHost.displayName
        $sourceHost = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.ownerRestoreInfo.ownerObject.entity.displayName
        $cloneInstance = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.instanceName

        if ($cloneDB -in $dbNames -and ($cloneHost -eq $dbServer -or $sourceHost -eq $dbServer) -and $cloneInstance -eq $instance){
            "Tearing down SQLDB: $cloneDB from $dbServer..."
            $foundDBs = @($foundDBs + $cloneDB)
            $taskId = $thisTaskId
            teardown $taskId
        }
    }

    # tear down Oracle clone
    if($cloneType -eq 'oracle'){
    
        $cloneDB = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.newDatabaseName
        $cloneHost = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.targetHost.displayName
        
        if ($cloneDB -in $dbNames -and $cloneHost -eq $dbServer){
            "Tearing down ORacle DB: $cloneDB from $cloneHost..."
            $foundDBs = @($foundDBs + $cloneDB)
            $taskId = $thisTaskId
            teardown $taskId
        }
    }

    # tear down view
    if($cloneType -eq 'view'){
        
        $cloneViewName = $clone.restoreTask.performRestoreTaskState.fullViewName
        
        if ($cloneViewName -eq $viewName){
            "Tearing down View: $cloneViewName..."
            $null = api delete views/$cloneViewName
            exit 0
        }
    }

    # tear down clone VMs
    if($cloneType -eq 'vm'){
        
        foreach ($vm in $clone.restoreTask.performRestoreTaskState.restoreInfo.restoreEntityVec){
            if($vm.restoredEntity.vmwareEntity.name -ieq $vmName){
                "Tearing down VM: $vmName..."
                $taskId = $thisTaskId
                teardown $taskId
                exit 0
            }
        }
    }

    # tear down azure vm
    if($cloneType -eq 'azure_vm'){
        foreach($vm in $clone.restoreTask.performRestoreTaskState.objects){
            if($vmName -eq "$($clone.restoreTask.performRestoreTaskState.renameRestoredObjectParam.prefix)$($vm.entity.displayName)"){
                "Tearing down Azure VM: $($clone.restoreTask.performRestoreTaskState.renameRestoredObjectParam.prefix)$($vm.entity.displayName)..."
                $taskId = $thisTaskId
                teardown $taskId
                exit 0
            }
        }
    }
    # tear down oracle view
    if($cloneType -eq 'oracle_view'){
        $cloneTaskName = $clone.restoreTask.performRestoreTaskState.base.name
        $cloneViewName = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.oracleCloneAppViewParamsVec[0].mountPathIdentifier
        if($cloneViewName -eq $viewName){
            "Tearing down View: $cloneViewName..."
            $taskId = $thisTaskId
            teardown $taskId
            exit 0
        }
    }
}

if ($cloneType -eq 'sql' -or $cloneType -eq 'oracle'){
    $returncode = 0
    foreach($db in $dbNames){
        if($db -notin $foundDBs){
            Write-Host "clone $db not found" -foregroundcolor Yellow
            $returncode = 1
        }
    }
    exit $returncode
}

if ($cloneType -eq 'view' -or $cloneType -eq 'oracle_view'){
    Write-Host "view $viewName not found" -ForegroundColor Yellow
    exit 1
}

if ($cloneType -eq 'vm' -or $cloneType -eq 'azure_vm'){
    Write-Host "vm $vmName not found" -ForegroundColor Yellow
    exit 1
}

exit 0
