
### usage: ./destroyClone.ps1 -vip 192.168.1.198 -username admin [ -domain local ] -cloneType { sql | view | vm } [ -viewName myview ] [ -vmName myvm ] [ -dbName mydb ] [ -dbServer myDBserver ] [ -instance MSSQLSERVER ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][ValidateSet('sql','view','vm')][string]$cloneType,
    [Parameter()][string]$viewName = '', #name of clone view to tear down
    [Parameter()][string]$vmName = '', #name of clone VM to tear down
    [Parameter()][string]$dbName = '', #name of clone DB to tear down
    [Parameter()][string]$dbServer = '', #name of dbServer where clone is attached
    [Parameter()][string]$instance = 'MSSQLSERVER'
)

if ($cloneType -eq 'sql'){
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
apiauth -vip $vip -username $username -domain $domain

$cloneTypes = @{ 'vm' = 2; 'view' = 5; 'sql' = 7 }

$taskId = $null

###get list of active clones
$clones = api get ("/restoretasks?restoreTypes=kCloneView&" +
                                "restoreTypes=kConvertAndDeployVMs&" +
                                "restoreTypes=kCloneApp&" +
                                "restoreTypes=kCloneVMs") `
                                | where-object { $_.restoreTask.destroyClonedTaskStateVec -eq $null } `
                                | Where-Object { $_.restoreTask.performRestoreTaskState.base.type -eq $cloneTypes[$cloneType]} `
                                | Where-Object { $_.restoreTask.performRestoreTaskState.base.publicStatus -eq 'kSuccess' }

### tear down matching clone
foreach ($clone in $clones){

    $thisTaskId = $clone.restoreTask.performRestoreTaskState.base.taskId

    ### tear down SQL clone
    if($cloneType -eq 'sql'){
        
        $cloneDB = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.newDatabaseName
        $cloneHost = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.targetHost.displayName
        $cloneInstance = $clone.restoreTask.performRestoreTaskState.restoreAppTaskState.restoreAppParams.restoreAppObjectVec[0].restoreParams.sqlRestoreParams.instanceName
    
        if ($cloneDB -ieq $dbName -and $cloneHost -ieq $dbServer -and $cloneInstance -ieq $instance){
            "tearing down SQLDB: $cloneDB from $cloneHost..."
            $taskId = $thisTaskId
        }
    }

    ### tear down view
    if($cloneType -eq 'view'){
        
        $cloneViewName = $clone.restoreTask.performRestoreTaskState.fullViewName
        
        if ($cloneViewName -eq $viewName){
            "tearing down View: $cloneViewName..."
            $result = api delete views/$cloneViewName
            exit
        }
    }

    ### tear down clone VMs
    if($cloneType -eq 'vm'){
        
        foreach ($vm in $clone.restoreTask.performRestoreTaskState.restoreInfo.restoreEntityVec){
            if($vm.restoredEntity.vmwareEntity.name -ieq $vmName){
                "tearing down VM: $vmName..."
                $taskId = $thisTaskId
            }
        }
    }
}

if ($taskId) {
    $result = api post "/destroyclone/$taskId"
}else{
    write-host "Clone Not Found" -foregroundcolor yellow
}
