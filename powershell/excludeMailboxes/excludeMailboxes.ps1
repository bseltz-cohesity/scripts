# usage: ./excludeMailboxes.ps1 -vip mycluster -username myusername -jobName 'My Job' -userList ./excludedMailboxes.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to exclude mailboxes from
    [Parameter()][array]$users = $null,  # comma separated list of users to exclude
    [Parameter()][string]$userList = ''  # text file of users to exclude
)

# gather list of users to add to job
$exclusions = @()
foreach($user in $users){
    $exclusions += $user
}
if ('' -ne $userList){
    if(Test-Path -Path $userList -PathType Leaf){
        $users = Get-Content $userList
        foreach($user in $users){
            $exclusions += [string]$user
        }
    }else{
        Write-Warning "User list $userList not found!"
        exit
    }
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get the protectionJob
$job = api get protectionJobs | Where-Object {$_.name -ieq $jobName}
if(!$job){
    Write-Warning "Job $jobName not found!"
    exit
}

# get physical protection sources
$source = api get "protectionSources?id=$($job.parentSourceId)"

$nodes = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}

if(! $job.PSObject.Properties['excludeSourceIds']){
    $job | Add-Member -MemberType NoteProperty -Name excludeSourceIds -Value @()
}

$exclusionsAdded = $false
foreach ($excludeUser in $exclusions){
    $node = $nodes.nodes | Where-Object { $_.protectionSource.name -eq $excludeUser -or $_.protectionSource.office365ProtectionSource.primarySMTPAddress -eq $excludeUser }
    if($node){
        if(!($node.protectionSource.id -in $job.excludeSourceIds) -or $node.protectionSource.id -in $job.sourceIds){
            $exclusionsAdded = $True
            $job.excludeSourceIds = @($job.excludeSourceIds + $node.protectionSource.id)
            $job.sourceIds = @($job.sourceIds | Where-Object {$_ -ne $node.protectionSource.id})
            write-host "Excluding $($node.protectionSource.name)" -ForegroundColor Green
        }else{
            write-host "$($node.protectionSource.name) already excluded" -ForegroundColor Green
        }
    }else{
        Write-host "Can't find user $excludeUser - skipping" -ForegroundColor Yellow
    }
}

if($exclusionsAdded){
    $null = api put "protectionJobs/$($job.id)" $job
}

