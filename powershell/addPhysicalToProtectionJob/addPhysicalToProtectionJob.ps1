# usage: ./addPhysicalToProtectionJob.ps1 -vip mycluster -username myusername -jobName 'My Job' -serverList ./servers.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$server = '',  # optional name of one server protect
    [Parameter()][string]$serverList = '',  # optional textfile of servers to protect
    [Parameter(Mandatory = $True)][string]$jobName  # name of the job to add server to
)

# gather list of servers to add to job
$serversToAdd = @()
if ('' -ne $server){
    $serversToAdd += $server
}
if ('' -ne $serverList){
    if(Test-Path -Path $serverList -PathType Leaf){
        $serversToAdd = Get-Content $serverList
    }
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
$sources = api get protectionSources?environment=kPhysical

# add sourceIds for new servers
$sourceIds = @($job.sourceIds)

foreach($server in $serversToAdd){
    $node = $sources.nodes | Where-Object { $_.protectionSource.name -eq $server }
    if($node){
            write-host "adding $server to $jobName..."
            $sourceId = $node.protectionSource.id
            $sourceIds += $sourceId
    }else{
        Write-Warning "$server is not a registered source"
    }
}

$sourceIds = @($sourceIds | Select-Object -Unique)

# update job
$job.sourceIds = @($sourceIds)
$null = api put "protectionJobs/$($job.id)" $job
