# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'Ccs',
    [Parameter(Mandatory = $True)][string]$region,  # Ccs region
    [Parameter()][string]$environment,
    [Parameter()][string]$subType
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

foreach($activity in $activities | Where-Object {! $_.PSObject.Properties['endTimeUsecs']}){
    if(! $activity.archivalRunParams.PSObject.Properties['endTimeUsecs']){
        if(!$subType -or $activity.archivalRunParams.protectionEnvironmentType -eq $subType){
            Write-host "Cancelling backup for $($activity.object.name)"
            $cancel = api post -v2 "data-protect/objects/runs/cancel" @{"objectRuns" = @(@{"objectId" = $activity.object.id})}
        }
    }
}
