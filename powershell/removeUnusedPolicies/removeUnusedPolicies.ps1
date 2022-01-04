# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# outfile
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "log-removeUnusedPolicies-$dateString.txt"

$policies = api get protectionPolicies
$jobs = api get protectionJobs

foreach($policy in $policies){
    if($policy.id -notin $jobs.policyId){
        "Deleting $($policy.name)" | Tee-Object -FilePath $outfileName -Append
        $null = api delete protectionPolicies/$($policy.id)
    }
}

"`nOutput saved to $outfilename`n"
