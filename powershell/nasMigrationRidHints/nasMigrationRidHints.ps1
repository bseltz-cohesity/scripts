# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,          # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,     # username (local or AD)
    [Parameter()][string]$domain = 'local',              # local or AD domain
    [Parameter()][int]$daysAgo = 1                       # days back to search for recoveries
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$daysAgoUsecs = dateToUsecs (get-date).AddDays(-$daysAgo)

# get restore tasks
$restoreTasks = api get "/restoretasks?_includeTenantInfo=true&startTimeUsecs=$daysAgoUsecs&targetType=kLocal" | Where-Object {
    $_.restoreTask.performRestoreTaskState.base.type -eq 10
}

$views = api get views
$viewNames = @()

"" | Tee-Object -FilePath ".\nasMigrationReport.txt"

foreach($task in $restoreTasks){

    # get properties of recovery task
    $jobId = $task.restoreTask.performRestoreTaskState.objects[0].jobId
    $startTimeUsecs = $task.restoreTask.performRestoreTaskState.objects[0].startTimeUsecs
    $entityName = $task.restoreTask.performRestoreTaskState.objects[0].entity.displayName
    $viewName = $task.restoreTask.performRestoreTaskState.fullViewName

    if($viewName -notin $viewNames){ # do not repeat the same view if recovered more than once
        $viewNames += $viewName
        $view = $views.views | Where-Object name -eq $viewName
        if($view){
            $viewProtectionJobName = $null
            if($view.viewProtection){
                $viewProtectionJobName = $view.viewProtection.protectionJobs[-1].jobName
            }
            if($viewProtectionJobName){
                
                # get nas job run that was used to recover the view
                $jobRun = api get "/backupjobruns?allUnderHierarchy=true&exactMatchStartTimeUsecs=$startTimeUsecs&id=$jobId"
                
                # get the reeplication task id from the job run
                $replTasks = $jobRun.backupJobRuns.protectionRuns[0].copyRun.finishedTasks | Where-Object {$_.snapshotTarget.type -eq 2}
                $subTasks = $replTasks.finishedCopySubTasks | Where-Object {$_.entity.displayName -eq $entityName}

                "--------`n`nView Protection Job: {0}`nView Name: {1}`nNAS Job ID: {2}`nNAS Entity: {3}" -f $viewProtectionJobName, $viewName, $jobId, $entityName | Tee-Object -FilePath ".\nasMigrationReport.txt" -Append

                # construct the gflag value
                $gflagValue = "dummy:dummy:dummy:1"

                foreach($subTask in $subTasks){
                    $rid = $subTask.taskUid.objectId
                    $remoteCluster = $subTask.snapshotTarget.replicationTarget.clusterName
                    $entry = ",{0}:{1}:{2}:{3}" -f $viewProtectionJobName, $viewName, $remoteCluster, $rid
                    $gflagValue += $entry
                    "Replication ID: {0} ({1})" -f $rid, $remoteCluster | Tee-Object -FilePath ".\nasMigrationReport.txt" -Append
                }

                # output the gflag syntax
                $irisCmd = "iris_cli cluster update-gflag gflag-name=bridge_madrox_ancestor_rid_hint gflag-value=""$gflagValue"" reason=""madrox seed"" effective-now=true service-name=bridge"
                "`n{0}`n" -f $irisCmd | Tee-Object -FilePath ".\nasMigrationReport.txt" -Append

            }else{
                Write-Host "View $viewName not found" -ForegroundColor Yellow
                continue
            }
        }
    }
}

# output cleanup command
"--------`n`nClean Up Gflag:`n" | Tee-Object -FilePath ".\nasMigrationReport.txt" -Append
"iris_cli cluster update-gflag gflag-name=bridge_madrox_ancestor_rid_hint clear=true reason=""madrox seed"" effective-now=true service-name=bridge`n" | Tee-Object -FilePath ".\nasMigrationReport.txt" -Append
