
### usage: ./destroyClone.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -cloneType { sql | view | vm } [ -viewName myview ] [ -vmName myvm ] [ -dbName mydb ] [ -dbServer myDBserver ] [ -instance MSSQLSERVER ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter(Mandatory = $True)][ValidateSet('sql','view','vm','oracle')][string]$cloneType,
    [Parameter()][string]$viewName = '', #name of clone view to tear down
    [Parameter()][string]$vmName = '', #name of clone VM to tear down
    [Parameter()][string]$dbName = '', #name of clone DB to tear down
    [Parameter()][string]$dbServer = '', #name of dbServer where clone is attached
    [Parameter()][string]$instance = 'MSSQLSERVER',
    [Parameter()][switch]$wait
)

if ($cloneType -eq 'sql' -or $cloneType -eq 'oracle'){
    if($dbName -eq '' -or $dbServer -eq ''){
        write-host "dbName and dbServer parameters required" -foregroundcolor yellow
        exit
    }
}

if ($cloneType -eq 'view'){
    if($viewName -eq ''){
        write-host "viewName parameter required" -foregroundcolor yellow
        exit  
    }
}

if ($cloneType -eq 'vm'){
    if($vmName -eq ''){
        write-host "vmName parameter required" -foregroundcolor yellow
        exit  
    }
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

$cloneTypes = @{ 'vm' = 2; 'view' = 5; 'sql' = 7 ; 'oracle' = 7}

$taskId = $null

### get list of active clones
$clones = api get ("/restoretasks?restoreTypes=kCloneView&" +
                                "restoreTypes=kCloneApp&" +
                                "restoreTypes=kCloneVMs") `
                                | where-object { $_.restoreTask.destroyClonedTaskStateVec -eq $null } `
                                | Where-Object { $_.restoreTask.performRestoreTaskState.base.type -eq $cloneTypes[$cloneType]} `
                                | Where-Object { $_.restoreTask.performRestoreTaskState.base.publicStatus -eq 'kSuccess' }

### find matching clone
foreach ($clone in $clones){

    $thisTaskId = $clone.restoreTask.performRestoreTaskState.base.taskId
    $thisClone = api get "/restoretasks/$thisTaskId"

    ### tear down SQL clone
    if($cloneType -eq 'sql'){
        
        $cloneDB = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.newDatabaseName
        $cloneHost = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.targetHost.displayName
        $sourceHost = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.ownerRestoreInfo.ownerObject.entity.displayName
        $cloneInstance = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.instanceName

        if ($cloneDB -eq $dbName -and ($cloneHost -eq $dbServer -or $sourceHost -eq $dbServer) -and $cloneInstance -eq $instance){
            "tearing down SQLDB: $cloneDB from $dbServer..."
            $taskId = $thisTaskId
            break
        }
    }

    ### tear down Oracle clone
    if($cloneType -eq 'oracle'){
    
        $cloneDB = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.oracleRestoreParams.alternateLocationParams.newDatabaseName
        $cloneHost = $thisClone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.targetHost.displayName
        
        if ($cloneDB -eq $dbName -and $cloneHost -eq $dbServer){
            "tearing down ORacle DB: $cloneDB from $cloneHost..."
            $taskId = $thisTaskId
            break
        }
    }

    ### tear down view
    if($cloneType -eq 'view'){
        
        $cloneViewName = $clone.restoreTask.performRestoreTaskState.fullViewName
        
        if ($cloneViewName -eq $viewName){
            "tearing down View: $cloneViewName..."
            $null = api delete views/$cloneViewName
            exit 0
        }
    }

    ### tear down clone VMs
    if($cloneType -eq 'vm'){
        
        foreach ($vm in $clone.restoreTask.performRestoreTaskState.restoreInfo.restoreEntityVec){
            if($vm.restoredEntity.vmwareEntity.name -ieq $vmName){
                "tearing down VM: $vmName..."
                $taskId = $thisTaskId
                break
            }
        }
    }
}

if ($taskId) {
    $restoreTask = api post "/destroyclone/$taskId"
    if($wait){
        while($restoreTask.restoreTask.destroyClonedTaskStateVec[0].status -eq 1){
            Start-Sleep 5
            $restoreTask = api get "/restoretasks/$taskId"
        }
        Write-Host "Clone Destroyed"
    }
    exit 0
}else{
    write-host "Clone Not Found" -foregroundcolor yellow
    exit 1
}
