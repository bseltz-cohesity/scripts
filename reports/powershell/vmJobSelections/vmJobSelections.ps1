# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',   # the cluster to connect to (DNS name or IP)
    [Parameter()][string]$username = 'helios',           # username (local or AD)
    [Parameter()][string]$domain = 'local',              # local or AD domain
    [Parameter()][switch]$useApiKey,                     # use API key for authentication
    [Parameter()][string]$password,                      # optional password
    [Parameter()][switch]$noPrompt,                      # do not prompt for password
    [Parameter()][string]$tenant,                        # org to impersonate
    [Parameter()][switch]$mcm,                           # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,               # MFA code
    [Parameter()][switch]$emailMfaCode,                  # email MFA code
    [Parameter()][string]$clusterName = $null,           # helios cluster to access
    [Parameter()][int]$numRuns = 20
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "VMSelections-$($cluster.name)-$dateString.csv"

# headings
"""Job Name"",""vCenter Name"",""VM Name""" | Out-File -FilePath $outfileName

$jobs = (api get -v2 'data-protect/protection-groups?environments=kVMware&isActive=true').protectionGroups

foreach($job in $jobs){
    $protectedVMs = @()
    $jobName = $job.name
    $vCenterName = $job.vmwareParams.sourceName
    $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?includeObjectDetails=true&numRuns=$numRuns"
    $protectedVMs = $runs.runs.objects.object.name | Sort-Object -Unique
    foreach($protectedVM in $protectedVMs){
        """{0}"",""{1}"",""{2}""" -f $jobName, $vCenterName, $protectedVM | Out-File -FilePath $outfileName -Append
    }
}

Write-Host "Output saved to $outfileName"
