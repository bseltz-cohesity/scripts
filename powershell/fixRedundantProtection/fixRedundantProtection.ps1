# usage: ./fixRedundantProtection.ps1 -vip myCluster -username myUser -jobName 'My Job' -fix

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$jobName,
    [Parameter()][switch]$fix
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

# get protectionJobs
$jobs = api get protectionJobs?isDeleted=false

# get specified job
$myJob = $jobs | Where-Object { $_.name -eq $jobName }
if(!$myJob){
    Write-Warning "Job $jobName not found!"
    exit
}

$redundanciesFound = $false
foreach ($job in @($jobs | Where-Object { $_.id -ne $myJob.id})){
    # find resundant source IDs
    $redundantSourceIds = $job.sourceIds | Where-Object { $_ -in $myJob.sourceIds }
    if($redundantSourceIds -and ! (($job.environment -eq 'kO365Exchange' -and $myJob.environment -eq 'kO365OneDrive') -or ($myJob.environment -eq 'kO365Exchange' -and $job.environment -eq 'kO365OneDrive'))){
        $redundanciesFound = $True
        "Found The following objects also protected in job: $($job.name):"
        # Display name of redundant source
        foreach ($sourceId in $redundantSourceIds){
            $source = api get "protectionSources/objects/$sourceId"
            "  $($source.name)"
        }
        if($fix){
            "  fixing..."
            # Remove redundant sources from the other job
            $job.sourceIds = @($job.sourceIds | Where-Object { $_ -notin $myJob.sourceIds })
            if($job.PSObject.Properties['sourceSpecialParameters']){
                $job.sourceSpecialParameters = @($job.sourceSpecialParameters | Where-Object { $_.sourceId -notin $myJob.sourceIds })
            }
            if($job.sourceIds.length -eq 0){
                Write-Warning "Can't remove $($source.name) from $($job.name) because it would leave the job empty. Please just delete the job."
            }else{
                $null = api put "protectionJobs/$($job.id)" $job
            }
        }
    }
}

if(!$redundanciesFound){
    "No redundancies found"
}


