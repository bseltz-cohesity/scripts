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
    [Parameter()][switch]$replaceRules
)

# gather list of servers to add to job
$jobNames = @()
foreach($j in $jobName){
    $jobNames += $j
}
if ('' -ne $jobList){
    if(Test-Path -Path $jobList -PathType Leaf){
        $jobs = Get-Content $jobList
        foreach($j in $jobs){
            $jobNames += [string]$j
        }
    }else{
        Write-Warning "Job list $jobList not found!"
        exit
    }
}
if($jobNames.Length -eq 0){
    Write-Host "No jobs specified" -ForegroundColor Yellow
    exit
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
if($exclusions.Length -eq 0){
    Write-Host "No exclusions specified" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get the protectionJob
$protectionGroups = api get "data-protect/protection-groups?isDeleted=false&includeTenants=true&includeLastRunInfo=true" -v2

foreach($jobName in $jobNames){
    $protectionGroup = $protectionGroups.protectionGroups | Where-Object name -eq $jobName
    if(!$protectionGroup){
        write-host "Job $jobName not found" -ForegroundColor Yellow
    }else{
        "Updating $jobName"
        if(!$replaceRules){
            $globalExcludePaths = $protectionGroup.physicalParams.fileProtectionTypeParams.globalExcludePaths
        }else{
            $globalExcludePaths = @()
        }
        foreach($excludePath in $exclusions){
            $globalExcludePaths += $excludePaths
        }
        $globalExcludePaths = @($globalExcludePaths | Sort-Object -Unique)
        setApiProperty -object $protectionGroup.physicalParams.fileProtectionTypeParams -name 'globalExcludePaths' -value $globalExcludePaths
        $null = api put "data-protect/protection-groups/$($protectionGroup.id)" $protectionGroup -v2
    }
}

        
