### usage: ./redundantProtectionReport.ps1 -vip mycluster -username myusername [ -domain local ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName
)

$outFile = $vip + '-redundantProtectionReport.csv'

### source the cohesity-api helper code
. ./cohesity-api

# authentication =============================================
# demand clusterName for Helios
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

"`nCollecting Report of Objects Protected by Multiple Jobs..."

### get protectionJobs
$jobs = api get protectionJobs?isDeleted=false

$sources = @{}

### get report
foreach ($job in $jobs){
    $report = api get reports/protectionSourcesJobsSummary?jobIds=$($job.id)
    foreach($summary in $report.protectionSourcesJobsSummary){
        if($summary.protectionSource.id -in $sources.Keys){
            $sources[$summary.protectionSource.id] += $job.name
        }else{
            $sources[$summary.protectionSource.id] = @($job.name)
        }
    }
}

$namedSources = @{}
$environments = @{}

### gather source names and types
foreach ($source in $sources.Keys){
    if ($sources[$source].Count -gt 1){
        $sourceObject = api get "protectionSources/objects/$source"
        $namedSources[$sourceObject.name] = $sources[$source]
        $environments[$sourceObject.name] = $sourceObject.environment.Substring(1)
    }
}

### display output
"`nObject (Type) Jobs"
"------------------`n"
foreach ($source in ($namedSources.Keys | Sort-Object )){
    "$source ($($environments[$source]))"
    foreach ($jobName in ($namedSources[$source] | Sort-Object)){
        "`t" + $jobName
    }
}

### write out to CSV file
"Object,Type,Protection Jobs" | Out-File $outFile
foreach ($source in ($namedSources.Keys | Sort-Object )){
    "$source,$($environments[$source]),$(($namedSources[$source] | Sort-Object) -join ',')" | Out-File $outFile -Append
}

"`nOutput Saved to $outFile`n"
