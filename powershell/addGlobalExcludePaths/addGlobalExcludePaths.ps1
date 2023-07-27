# usage: ./protectPhysicalLinux.ps1 -vip mycluster -username myusername -jobName 'My Job' -serverList ./servers.txt -exclusionList ./exclusions.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',  # endpoint to connect to
    [Parameter()][string]$username = 'helios',  # username for authentication / password storage
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,  # use API key authentication
    [Parameter()][string]$password = $null,  # send password / API key via command line (not recommended)
    [Parameter()][switch]$noPrompt,  # do not prompt for password
    [Parameter()][switch]$mcm,  # connect to MCM endpoint
    [Parameter()][string]$mfaCode = $null,  # MFA code
    [Parameter()][switch]$emailMfaCode,  # email MFA code
    [Parameter()][string]$clusterName = $null,  # cluster name to connect to when connected to Helios/MCM
    [Parameter()][array]$jobName,  # optional name of one server protect
    [Parameter()][string]$jobList = '',  # optional textfile of servers to protect
    [Parameter()][array]$exclusions,  # optional name of one server protect
    [Parameter()][string]$exclusionList = '',  # required list of exclusions
    [Parameter()][switch]$overwrite
)

# gather list of servers to add to job
$jobnames= @()
foreach($j in $jobName){
    $jobnames += $j
}
if ('' -ne $jobList){
    if(Test-Path -Path $jobList -PathType Leaf){
        $jobnamelist = Get-Content $jobList
        foreach($j in $jobnamelist){
            $jobnames += [string]$j
        }
    }else{
        Write-Warning "Job list $jobList not found!"
        exit
    }
}

# gather exclusion list
$excludePaths = @()
foreach($exclusion in $exclusions){
    $excludePaths += $exclusion
}
if('' -ne $exclusionList){
    if(Test-Path -Path $exclusionList -PathType Leaf){
        $exclusions = Get-Content $exclusionList
        foreach($exclusion in $exclusions){
            $excludePaths += [string]$exclusion
        }
    }else{
        Write-Warning "Exclusions file $exclusionList not found!"
        exit
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit
}

# get the protectionJobs

$jobs = (api get "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kPhysical&includeTenants=true" -v2).protectionGroups |
        Where-Object {$_.physicalParams.protectionType -eq 'kFile' -and $_.name -in $jobnames}
$missingJobs = $jobnames | Where-Object {$_ -notin @($jobs.name)}
if($missingJobs.Length -gt 0){
    foreach($j in $missingJobs){
        Write-Host "Job $j not found" -ForegroundColor Yellow
    }
    exit
}

foreach($job in $jobs){
    $globalExcludePaths = $job.physicalParams.fileProtectionTypeParams.globalExcludePaths
    if($null -eq $globalExcludePaths -or $overwrite){
        $job.physicalParams.fileProtectionTypeParams.globalExcludePaths = @($excludePaths | Sort-Object -Unique)
    }else{
        $job.physicalParams.fileProtectionTypeParams.globalExcludePaths = @($globalExcludePaths + $excludePaths | Sort-Object -Unique)
    }
    Write-Host "Updating job $($job.name)"
    $null = api put "data-protect/protection-groups/$($job.id)" $job -v2
}
