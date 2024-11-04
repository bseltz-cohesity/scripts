# usage: ./includeMailboxes.ps1 -vip mycluster -username myusername -jobName 'My Job' [ -users 'jbrown@mydomain.net', 'ksmith@mydomain.net' ] [ -userList ./usersToAdd.txt ]

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to exclude mailboxes from
    [Parameter()][array]$users = $null, # comma separated list of users to add
    [Parameter()][string]$userList = '',  # import users to add from a file
    [Parameter()][int]$pageSize = 1000
)

# gather list of users to add to job
$usersToAdd = @()
foreach($user in $users){
    $usersToAdd += $user
}
if ('' -ne $userList){
    if(Test-Path -Path $userList -PathType Leaf){
        $users = Get-Content $userList
        foreach($user in $users){
            $usersToAdd += [string]$user
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

# find O365 source
$rootSource = api get "protectionSources/rootNodes?environments=kO365&id=$($job.parentSourceId)"

$source = api get "protectionSources?id=$($rootSource.protectionSource.id)&excludeOffice365Types=kMailbox,kUser,kGroup,kSite,kPublicFolder,kO365Exchange,kO365OneDrive,kO365Sharepoint&allUnderHierarchy=false"
$usersNode = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}
if(!$usersNode){
    Write-Host "Source $sourceName is not configured for O365 Mailboxes" -ForegroundColor Yellow
    exit
}

$nameIndex = @{}
$smtpIndex = @{}
$indexCount = 0

Write-Host "Discovering users..."

$users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false"
while(1){
    foreach($node in $users.nodes){
        $nameIndex[$node.protectionSource.name] = $node.protectionSource.id
        $smtpIndex[$node.protectionSource.office365ProtectionSource.primarySMTPAddress] = $node.protectionSource.id
    }
    $cursor = $users.nodes[-1].protectionSource.id
    $users = api get "protectionSources?pageSize=$pageSize&nodeId=$($usersNode.protectionSource.id)&id=$($usersNode.protectionSource.id)&hasValidMailbox=true&allUnderHierarchy=false&afterCursorEntityId=$cursor"
    if($smtpIndex.Keys.Count -eq $indexCount){
        break
    }
    $indexCount = $smtpIndex.Keys.Count
}

Write-Host "$($smtpIndex.Keys.Count) users discovered"

foreach($user in $usersToAdd){
    $userId = $null
    if($smtpIndex.ContainsKey($user)){
        $userId = $smtpIndex[$user]
    }elseif($nameIndex.ContainsKey($user)){
        $userId = $nameIndex[$user]
    }
    if($userId){
        if(!($userId -in $job.sourceIds)){
            $usersAdded = $True
            $job.sourceIds += $userId
            write-host "Adding $user" -ForegroundColor Green
        }else{
            write-host "$user already added" -ForegroundColor Green
        }
    }else{
        Write-Host "Can't find user $user - skipping" -ForegroundColor Yellow
    }
}

if($usersAdded){
    $null = api put "protectionJobs/$($job.id)" $job
}
