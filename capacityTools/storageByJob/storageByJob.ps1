[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'  # local or AD domain
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster

$jobs = api get protectionJobs

Write-Host "`nLocal Jobs...`n"
foreach($job in $jobs | Sort-Object -Property name){
    if($job.policyId.split(':')[0] -eq $cluster.id){
        $consumption = api get "stats/consumers?consumerType=kProtectionRuns&consumerIdList=$($job.id)"
        if($consumption.statsList){
            if($consumption.statsList.Count -gt 0){
                "{0,40}: {1,11:f2} {2}" -f $job.name, ($consumption.statsList[0].stats.storageConsumedBytes / (1024 * 1024 * 1024)), 'GB'
            }else{
                "{0,40}: {1,11:f2} {2}" -f $job.name, "0.00", 'GB'
            }
        }
    }
}

$views = api get views
Write-Host "`nUnprotected Views...`n"
foreach($view in $views.views | Sort-Object -Property name | Where-Object viewProtection -eq $null){
    $consumption = api get "stats/consumers?consumerType=kViews&consumerIdList=$($view.viewId)"
    if($consumption.statsList){
        if($consumption.statsList.Count -gt 0){
            "{0,40}: {1,11:f2} {2}" -f $view.name, ($consumption.statsList[0].stats.storageConsumedBytes / (1024 * 1024 * 1024)), 'GB'
        }else{
            "{0,40}: {1,11:f2} {2}" -f $view.name, "0.00", 'GB'
        }
    }
}

Write-Host "`nReplicated Jobs...`n"
foreach($job in $jobs | Sort-Object -Property name){
    if($job.policyId.split(':')[0] -ne $cluster.id){
        $consumption = api get "stats/consumers?consumerType=kReplicationRuns&consumerIdList=$($job.id)"
        if($consumption.statsList.Count -gt 0){
            "{0,40}: {1,11:f2} {2}" -f $job.name, ($consumption.statsList[0].stats.storageConsumedBytes / (1024 * 1024 * 1024)), 'GB'
        }else{
            "{0,40}: {1,11:f2} {2}" -f $job.name, "0.00", 'GB'
        }
    }
}
