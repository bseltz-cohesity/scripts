# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobname,
    [Parameter(Mandatory = $True)][string]$servername,
    [Parameter()][string]$policyname,
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/Los_Angeles', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalProtectionSlaTimeMins = 60,
    [Parameter()][int]$fullProtectionSlaTimeMins = 120,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain' #storage domain you want the new job to write to
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# root SQL source
$sources = api get protectionSources?environments=kSQL

# server source
$serverSource = $sources[0].nodes | Where-Object {$_.protectionSource.name -eq $servername}
if(! $serverSource){
    Write-Host "Server $serverSource not found!" -ForegroundColor
    Write-Host "Make sure to enter the server name exactly as listed in Cohesity" -ForegroundColor Yellow
    exit 1
}

# get the protectionJob
$job = api get protectionJobs | Where-Object name -eq $jobName

if(! $job){
    # create new job
    
    # get policy
    if(! $policyname){
        Write-Host "-policyname required when creating a new job" -ForegroundColor Yellow
        exit 1
    }
    $policy = api get protectionPolicies | Where-Object name -eq $policyname
    if(! $policy){
        Write-Host "Policy $policyname not found!" -ForegroundColor Yellow
        exit 1
    }

    # parse startTime
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
        exit
    }

    # get storageDomain
    $viewBoxes = api get viewBoxes
    if($viewBoxes -is [array]){
            $viewBox = $viewBoxes | Where-Object { $_.name -ieq $storageDomainName }
            if (!$viewBox) { 
                write-host "Storage domain $storageDomainName not Found" -ForegroundColor Yellow
                exit
            }
    }else{
        $viewBox = $viewBoxes[0]
    }

    $job = @{
        "name"                             = $jobname;
        "environment"                      = "kSQL";
        "policyId"                         = $policy.id;
        "viewBoxId"                        = $viewBox.id;
        "parentSourceId"                   = $sources[0].protectionSource.id;
        "sourceIds"                        = @(
            $serverSource.protectionSource.id
        );
        "startTime"                        = @{
            "hour"   = [int]$hour;
            "minute" = [int]$minute
        };
        "timezone"                         = $timeZone;
        "incrementalProtectionSlaTimeMins" = $incrementalProtectionSlaTimeMins;
        "fullProtectionSlaTimeMins"        = $fullProtectionSlaTimeMins;
        "priority"                         = "kMedium";
        "alertingPolicy"                   = @(
            "kFailure"
        );
        "indexingPolicy"                   = @{
            "disableIndexing" = $true
        };
        "performSourceSideDedup"           = $false;
        "qosType"                          = "kBackupHDD";
        "environmentParameters"            = @{
            "sqlParameters" = @{
                "userDatabasePreference"     = "kBackupAllDatabases";
                "backupSystemDatabases"      = $true;
                "aagPreferenceFromSqlServer" = $true;
                "backupType"                 = "kSqlVSSFile"
            }
        }
    }
    Write-Host "Creating job $jobname..."
    $null = api post protectionJobs $job
}else{
    # update existing job
    Write-Host "Updating job $jobname..."
    $job.sourceIds += $serverSource.protectionSource.id
    $null = api put protectionJobs/$($job.id) $job 
}
