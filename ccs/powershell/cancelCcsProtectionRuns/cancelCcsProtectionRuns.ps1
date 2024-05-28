# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region,  # DMaaS region
    [Parameter()][string]$environment,
    [Parameter()][string]$subType,
    [Parameter()][string]$objectName,
    [Parameter()][string]$sourceName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -regionid $region

$activityQuery = @{
    "statsParams" = @{
        "attributes" = @(
            "Status";
            "ActivityType"
        )
    };
    "statuses" = @(
        "Running";
        "Accepted"
    );
    "activityTypes" = @(
        "ArchivalRun";
        "BackupRun"
    )
}

if($environment){
    $activityQuery['environments'] = @($environment)
}

if($subType){
    $activityQuery['archivalRunParams'] = @{"protectionEnvironmentTypes" = @("$subType")}
}

$activities = api post -mcmv2 data-protect/objects/activity $activityQuery
$activities = $activities.activity | Where-Object {$_.archivalRunParams.status -eq 'Running' -or $_.archivalRunParams.status -eq 'Accepted'}
if(!$activities){
    Write-host "No active backups"
    exit
}

if($sourceName){
    $activities = $activities | Where-Object {$_.object.sourceName -eq $sourceName}
    if(!$activities){
        Write-host "No active backups for $sourceName"
        exit
    }
}

if($objectName){
    $activities = $activities | Where-Object {$_.object.name -eq $objectName}
    if(!$activities){
        Write-host "No active backups for $objectName"
        exit
    }
}

foreach($activity in $activities | Where-Object {! $_.PSObject.Properties['endTimeUsecs']}){
    if(! $activity.archivalRunParams.PSObject.Properties['endTimeUsecs']){
        if(!$subType -or $activity.archivalRunParams.protectionEnvironmentType -eq $subType){
            Write-host "Cancelling backup for $($activity.object.name)"
            $cancel = api post -v2 "data-protect/objects/runs/cancel" @{"objectRuns" = @(@{"objectId" = $activity.object.id})}
        }
    }
}
