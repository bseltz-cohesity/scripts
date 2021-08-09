# usage: ./protectPhysicalLinux.ps1 -vip mycluster -username myusername -jobName 'My Job' -serverList ./servers.txt -exclusionList ./exclusions.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][array]$jobName = '',  # optional name of one server protect
    [Parameter()][string]$jobList = '',  # optional textfile of servers to protect
    [Parameter()][array]$exclusions = '',  # optional name of one server protect
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
apiauth -vip $vip -username $username -domain $domain

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
