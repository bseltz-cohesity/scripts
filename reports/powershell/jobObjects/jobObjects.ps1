# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$numRuns = 10
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# output file
$cluster = api get cluster
$dateString = get-date -UFormat '%Y-%m-%d'
$outputfile = $(Join-Path -Path $PSScriptRoot -ChildPath "jobObjects-$($cluster.name)-$dateString.csv")
"Job Name,Job Type,Policy Name,Object Name" | Out-File -FilePath $outputfile

$jobs = api get protectionJobs | Where-Object {$_.isActive -ne $False -and $_.isDeleted -ne $True}
$policies = api get protectionPolicies

foreach($job in $jobs | Sort-Object -Property name){
    $policy = $policies | Where-Object id -eq $job.policyId
    "`n{0} ({1})`n" -f $job.name, $job.environment.subString(1)
    $info = api get "/backupjobruns?allUnderHierarchy=true&excludeTasks=true&numRuns=$numRuns&id=$($job.id)"
    $sources = $info.backupJobRuns.jobDescription.sources.entities.displayName | Sort-Object -Unique
    foreach($source in $sources){
        "  $source"
        "{0},{1},{2},{3}" -f $job.name, $job.environment.subString(1), $policy.name, $source | Out-File -FilePath $outputfile -Append
    }
}
"`nOutput saved to $outputfile`n"
