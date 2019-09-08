### usage: ./cloneList.ps1 -vip mycluster -username myusername -domain mydomain.net [ -olderThan 30 ] [ -tearDown ]
### omitting the -tearDown parameter: the script will only display the lit of existing clones
### including the -tearDown parameter: the script will actually tear down all clones! 

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$olderThan = 0, # show/tear down clones older than X days
    [Parameter()][switch]$tearDown # tear down clones!
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$clones = api get '/restoretasks?_includeTenantInfo=true&restoreTypes=kCloneApp&restoreTypes=kCloneVMs'

$clones = $clones | Where-Object {$_.restoreTask.destroyClonedTaskStateVec -eq $null -and 
                                  $_.restoreTask.performRestoreTaskState.base.publicStatus -eq 'kSuccess'}

$clones | ForEach-Object {

    $name = $_.restoreTask.performRestoreTaskState.base.name
    $startTime = $_.restoreTask.performRestoreTaskState.base.startTimeUsecs
    $taskId = $_.restoreTask.performRestoreTaskState.base.taskId

    if($startTime -lt (timeAgo $olderThan days)){
        "{0} - {1}" -f ((usecsToDate $startTime), $name)
        if($tearDown){
            write-host "`ttearing down..."
            $null = api post /destroyclone/$taskId
        }
    }
}
