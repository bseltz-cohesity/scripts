# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$username = 'DMaaS',
    [Parameter(Mandatory = $True)][string]$region  # DMaaS region
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -username $username -regionid $region

$activities = api post -mcmv2 data-protect/objects/activity
$activities = $activities.activity | Where-Object {$_.archivalRunParams.status -eq 'Running' -or $_.archivalRunParams.status -eq 'Accepted'}
foreach($activity in $activities){
    Write-host "Cancelling backup for $($activity.object.name)"
    $cancel = api post -v2 "data-protect/objects/runs/cancel" @{"objectRuns" = @(@{"objectId" = $activity.object.id})}
}
