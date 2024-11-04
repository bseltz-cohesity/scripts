# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName  # folder to store export files
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get job that has autoprotected VM folder
$job = (api get -v2 data-protect/protection-groups?environments=kVMware).protectionGroups | Where-Object {$_.name -eq $jobName}
if(! $job){
    Write-Host "Job $jobName not found or is not a VMware job" -ForegroundColor Yellow
    exit
}

$runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?includeObjectDetails=true&numRuns=3"
$vmlist = @()
foreach($run in $runs.runs){
    foreach($object in $run.objects.object){
        $vmlist = @($vmlist + $object.name)
    }
}
$vmlist = @($vmlist | Sort-Object -Unique)
$vmlist
