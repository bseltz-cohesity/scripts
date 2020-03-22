# usage: ./protectOracle.ps1 -vip mycluster -username myusername -jobName 'My Job' -servername server.mydomain.net -dbname db1

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobname,
    [Parameter(Mandatory = $True)][string]$servername,
    [Parameter()][string]$dbname = $null,
    [Parameter()][string]$policyname = $null,
    [Parameter()][string]$storagedomain = 'DefaultStorageDomain',
    [Parameter()][string]$timezone = "America/New_York",
    [Parameter()][string]$starttime = $null

)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# get Oracle sources
$sources = api get protectionSources?environments=kOracle

# get the protectionJob
if($policyname){
    # create new job based on existing job
    $policy = api get protectionPolicies | Where-Object {$_.name -ieq $policyname}
    if(!$policy){
        Write-Host "Policy $policyname not found!" -ForegroundColor Yellow
        exit
    }
    $sd = api get viewBoxes | Where-Object {$_.name -eq $storagedomain}
    if(!$sd){
        Write-Host "Storage domain $storagedomain not found!" -ForegroundColor Yellow
        exit
    }
    $job = @{
        "name"                             = $jobname;
        "environment"                      = "kOracle";
        "policyId"                         = $policy.id;
        "viewBoxId"                        = $sd.id;
        "parentSourceId"                   = $sources.protectionSource.id;
        "sourceIds"                        = @();
        "startTime"                        = @{
            "hour"   = 20;
            "minute" = 00
        };
        "timezone"                         = $timezone;
        "incrementalProtectionSlaTimeMins" = 60;
        "fullProtectionSlaTimeMins"        = 120;
        "priority"                         = "kMedium";
        "alertingPolicy"                   = @(
            "kFailure"
        );
        "indexingPolicy"                   = @{
            "disableIndexing" = $true
        };
        "sourceSpecialParameters"          = @();
        "qosType"                          = "kBackupHDD";
        "createRemoteView"                 = $false;
    }

    # set start time for new job
    if($starttime){
        $hours, $minutes = $starttime.split(':')
        if(!($hours -match "^[\d\.]+$" -and $hours -in 0..23) -or !($minutes -match "^[\d\.]+$" -and $minutes -in 0..59)){
            write-host 'Start time is invalid' -ForegroundColor Yellow
            exit
        }else{
            $job.startTime.hour = [int]$hours
            $job.startTime.minute = [int]$minutes
        }
    }
}else{
    # or add server/db to an existing job
    $job = api get protectionJobs | Where-Object {$_.name -ieq $jobname}
    if(!$job){
        Write-Warning "Job $jobName not found!"
        exit
    }
}

# find server to add to job
$server = $sources.nodes | Where-Object {$_.protectionSource.name -eq $servername}
if(!$server){
    Write-Warning "Server $servername not found!"
    exit
}
$serverId = $server.protectionSource.id
$job.sourceIds = @($job.sourceIds + $serverId | Select-Object -Unique)

if($dbname){
    # find db to add to job
    $db = $server.applicationNodes| Where-Object {$_.protectionSource.name -eq $dbname}
    if(!$db){
        Write-Warning "Database $dbname not found!"
        exit
    }
    $dbIds = @($db.protectionSource.id)
    write-host "Adding $servername/$dbname to protection job $jobname..."
}else{
    # or add all dbs to job
    $dbIds = @($server.applicationNodes.protectionSource.id)
    write-host "Adding $servername/* to protection job $jobname..."
}

# update dblist for server
$sourceSpecialParameter = $job.sourceSpecialParameters | Where-Object {$_.sourceId -eq $serverId }
if(!$sourceSpecialParameter){
    $job.sourceSpecialParameters += @{"sourceId" = $serverId; "oracleSpecialParameters" = @{"applicationEntityIds" = $dbIds}}
}else{
    $sourceSpecialParameter.oracleSpecialParameters.applicationEntityIds += $dbIds | Select-Object -Unique
    $sourceSpecialParameter.oracleSpecialParameters.applicationEntityIds = @($sourceSpecialParameter.oracleSpecialParameters.applicationEntityIds | Where-Object {$_ -in $server.applicationNodes.protectionSource.id})
}

if($policyname){
    # create new job
    $null = api post protectionJobs $job
}else{
    # update existing job
    $null = api put "protectionJobs/$($job.id)" $job
}
