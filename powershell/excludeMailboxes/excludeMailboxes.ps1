# usage: ./excludeMailboxes.ps1 -vip mycluster -username myusername -domain mydomain.net -jobName 'My Job' -exclusionList ./excludedMailboxes.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to exclude mailboxes from
    [Parameter()][string]$exclusionList = './excludedMailboxes.txt'  # list of user names who's mailboxes to exclude
)

if(Test-Path -Path $exclusionList -PathType Leaf){
    $exclusions = Get-Content $exclusionList
}else{
    write-host "Can't find file $exclusionList" -ForegroundColor Yellow
    exit
}

# source the cohesity-api helper code
. ./cohesity-api

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

foreach ($excludeUser in $exclusions){
    $node = $source.nodes[0].nodes | Where-Object { $_.protectionSource.name -eq $excludeUser -or $_.protectionSource.office365ProtectionSource.primarySMTPAddress -eq $excludeUser }
    if($node){
        if(!($node.protectionSource.id -in $job.excludeSourceIds)){
            $job.excludeSourceIds += $node.protectionSource.id
            write-host "Excluding $($node.protectionSource.name)" -ForegroundColor Green
        }else{
            write-host "$($node.protectionSource.name) already excluded" -ForegroundColor Green
        }
    }else{
        Write-host "Can't find user $excludeUser - skipping" -ForegroundColor Yellow
    }
}

$null = api put "protectionJobs/$($job.id)" $job
