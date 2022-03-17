# usage: ./includeMailboxes.ps1 -vip mycluster -username myusername -jobName 'My Job' [ -users 'jbrown@mydomain.net', 'ksmith@mydomain.net' ] [ -userList ./usersToAdd.txt ]

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to exclude mailboxes from
    [Parameter()][array]$users = $null, # comma separated list of users to add
    [Parameter()][string]$userList = ''  # import users to add from a file
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

# get physical protection sources
$source = api get "protectionSources?id=$($job.parentSourceId)"

$nodes = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Users'}

$usersAdded = $false
foreach ($user in $usersToAdd){
    $node = $nodes.nodes | Where-Object { $_.protectionSource.name -eq $user -or $_.protectionSource.office365ProtectionSource.primarySMTPAddress -eq $user }
    if($node){
        if(!($node.protectionSource.id -in $job.sourceIds)){
            $usersAdded = $True
            $job.sourceIds += $node.protectionSource.id
            write-host "Adding $($node.protectionSource.name)" -ForegroundColor Green
        }else{
            write-host "$($node.protectionSource.name) already added" -ForegroundColor Green
        }
    }else{
        Write-host "Can't find user $user - skipping" -ForegroundColor Yellow
    }
}

if($usersAdded){
    $null = api put "protectionJobs/$($job.id)" $job
}
