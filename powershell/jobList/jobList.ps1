### usage: .\jobList.ps1 -vip mycluster -username myusername -domain mydomain.net

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$jobName,
    [Parameter()][string]$domain = 'local'
 )

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

### get protection jobs and policies
$jobs = api get protectionJobs?isActive=true

if($jobName){
    $jobs = $jobs | Where-Object name -eq $jobName
}

$policies = api get protectionPolicies
$cluster = api get cluster

$outfile = "$($cluster.name)-jobList.csv"
# write-host "Saving Job Retention Settings to $vip-jobRetentionReport.csv"
"Job Name,Job ID,Job Type,Policy Name" | Out-File -FilePath $outfile

foreach($job in $jobs | Sort-Object -Property name){
    $jobName = $job.name
    $jobName
    $jobId = $job.id
    $jobType = $job.environment.subString(1) 
    $policyId = $job.policyId
    $policy = $policies | Where-Object {$_.id -eq $policyId}
    $policyName = $policy.name
    "$jobName,$jobId,$jobType,$policyName" | out-file -FilePath $outfile -Append
}

write-host "Job List saved to $outfile"