### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$snowurl,
    [Parameter(Mandatory = $True)][string]$snowuser,
    [Parameter()][string]$snowcreds = '.\snowcreds.xml',
    [Parameter()][int]$strikes = 3
)

# Install-Module servicenow 

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate to Cohesity
apiauth -vip $vip -username $username -domain $domain

# authenticate to ServiceNow
New-ServiceNowSession -Credential $(Import-Clixml -Path $snowcreds) -Url $snowurl

function sendAlerts($clusterName){
    write-host "$clusterName"
    # get protection jobs
    $jobs = api get protectionJobs?allUnderHierarchy=true | Sort-Object -Property name | Where-Object {$_.isDeleted -ne $True -and $_.isActive -ne $False}

    $finishedStates = @('kCanceled', 'kSuccess', 'kFailure', 'kWarning')
    $unsuccessfulStates = @('kCanceled', 'kFailure')

    foreach($job in $jobs){
        Write-Host "    $($job.name)"
        # get protection runs
        $runs = api get "protectionRuns?jobId=$($job.id)&excludeTasks=true&numRuns=$($strikes + 1)"
        if($runs.count -gt 0){
            $successfulRuns = $runs | Where-Object {$_.backupRun.status -notin $unsuccessfulStates}
            if(! $successfulRuns){
                $unsuccessfulRuns = $runs | Where-Object {$_.backupRun.status -in $unsuccessfulStates}
                # trigger alert if we have enough strikes
                if($unsuccessfulRuns.count -ge $strikes){
                    $incidentShortDescription = "Cohesity protection job '$($job.name)' on cluster $clusterName is failing"
                    $incidentDescription = "Cohesity protection job '$($job.name)' on cluster $clusterName is failing. Last error is '$($unsuccessfulRuns[0].backupRun.error)'"
                    $existingIncidents = Get-ServiceNowIncident -MatchContains @{short_description=$incidentShortDescription} | Where-Object {$_.state -ne 'Resolved'}
                    if(! $existingIncidents){
                        Write-Host "        failed $($unsuccessfulRuns.count) times - creating new ServiceNow incident..."
                        New-ServiceNowIncident -Caller $snowuser -ShortDescription $incidentShortDescription -Description $incidentDescription
                    }else{
                        Write-Host "        failed $($unsuccessfulRuns.count) times - ServiceNow incident already exists"
                    }
                }
            }
        }
    }
}

if($vip -eq 'helios.cohesity.com'){
    foreach($cluster in heliosClusters){
        heliosCluster $cluster
        $clusterName = $cluster.name.ToUpper()
        sendAlerts $clusterName
    }
}else{
    $cluster = api get cluster
    $clusterName = $cluster.name.ToUpper()
    sendAlerts $clusterName
}

