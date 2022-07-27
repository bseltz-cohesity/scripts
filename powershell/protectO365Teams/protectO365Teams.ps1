# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to exclude mailboxes from
    [Parameter()][array]$teams = $null, # comma separated list of users to add
    [Parameter()][string]$teamList = ''  # import users to add from a file
)

# gather list of users to add to job
$teamsToAdd = @()
foreach($team in $teams){
    $teamsToAdd += $team
}
if ('' -ne $teamList){
    if(Test-Path -Path $teamList -PathType Leaf){
        $teams = Get-Content $teamList
        foreach($team in $teams){
            $teamsToAdd += [string]$team
        }
    }else{
        Write-Warning "User list $teamList not found!"
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
    Write-Host "Job $jobName not found!" -ForegroundColor Yellow
    exit
}
if($job.environment -ne 'kO365Teams'){
    Write-Host "Job $jobName is not an O365 Teams job" -ForegroundColor Yellow
    exit
}

# get physical protection sources
$source = api get "protectionSources?id=$($job.parentSourceId)"

$nodes = $source.nodes | Where-Object {$_.protectionSource.name -eq 'Teams'}

$teamsAdded = $false
foreach ($team in $teamsToAdd){
    $node = $nodes.nodes | Where-Object { $_.protectionSource.name -eq $team -or $_.protectionSource.office365ProtectionSource.primarySMTPAddress -eq $team }
    if($node){
        if(!($node.protectionSource.id -in $job.sourceIds)){
            $teamsAdded = $True
            $job.sourceIds += $node.protectionSource.id
            write-host "Adding $($node.protectionSource.name)" -ForegroundColor Green
        }else{
            write-host "$($node.protectionSource.name) already added" -ForegroundColor Green
        }
    }else{
        Write-host "Can't find team $team - skipping" -ForegroundColor Yellow
    }
}

if($teamsAdded){
    "Updating protection job"
    $null = api put "protectionJobs/$($job.id)" $job
}
