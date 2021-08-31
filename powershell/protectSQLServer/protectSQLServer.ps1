# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobname,
    [Parameter()][array]$servername,
    [Parameter()][string]$serverList = '',  # optional textfile of servers to protect
    [Parameter()][array]$instanceName,
    [Parameter()][switch]$instancesOnly,
    [Parameter()][string]$policyname,
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/Los_Angeles', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalProtectionSlaTimeMins = 60,
    [Parameter()][int]$fullProtectionSlaTimeMins = 120,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain' #storage domain you want the new job to write to
)

# gather list of servers to add to job
$serversToAdd = @()
foreach($server in $servername){
    $serversToAdd += $server
}
if ('' -ne $serverList){
    if(Test-Path -Path $serverList -PathType Leaf){
        $servers = Get-Content $serverList
        foreach($server in $servers){
            $serversToAdd += [string]$server
        }
    }else{
        Write-Warning "Server list $serverList not found!"
        exit
    }
}
if($serversToAdd.Length -eq 0){
    Write-Host "No servers to add"
    exit
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -password $password

# root SQL source
$sources = api get protectionSources?environments=kSQL

# get the protectionJob
$job = api get protectionJobs | Where-Object name -eq $jobName
$newJob = $false

if(! $job){
    # create new job
    Write-Host "Creating job $jobname..."
    $newJob = $True

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
        "sourceIds"                        = @();
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

}else{
    Write-Host "Updating job $jobname..."
}

# server source
foreach($servername in $serversToAdd){
    $serverSource = $sources[0].nodes | Where-Object {$_.protectionSource.name -eq $servername}
    if(! $serverSource){
        Write-Host "Server $serverSource not found!" -ForegroundColor
        Write-Host "Make sure to enter the server name exactly as listed in Cohesity" -ForegroundColor Yellow
        exit 1
    }
    
    # instances
    $haveParams = $false
    $mySourceParams = @{
        "sourceId" = $serverSource.protectionSource.id;
        "sqlSpecialParameters" = @{
            "applicationEntityIds" = @()
        }
    }
    
    if($instanceName.Count -eq 0 -and $instancesOnly){
        $mySourceParams.sqlSpecialParameters.applicationEntityIds = @($serverSource.applicationNodes.protectionSource.id)
        $haveParams = $True
    }else{
        foreach($instance in $instanceName){
            $instanceSource = $serverSource.applicationNodes | Where-Object {$_.protectionSource.name -eq $instance}
            if(! $instanceSource){
                Write-Host "Instance $instance not found on server $servername"
                exit
            }else{
                $mySourceParams.sqlSpecialParameters.applicationEntityIds += $instanceSource.protectionSource.id
                $haveParams = $True
            }
        }
    }

    if($haveParams){
        if(! $job.PSObject.Properties['sourceSpecialParameters']){
            setApiProperty -object $job -name 'sourceSpecialParameters' -value @($mySourceParams)
        }else{
            $existingParams = $job.sourceSpecialParameters | Where-Object {$_.sourceId -eq $serverSource.protectionSource.id}
            if($existingParams){
                $existingParams.sqlSpecialParameters.applicationEntityIds += @($mySourceParams.sqlSpecialParameters.applicationEntityIds | Sort-Object -Unique)
            }else{
                $job.sourceSpecialParameters += $mySourceParams
            }
        }
    }

    $job.sourceIds += @($job.sourceIds + $serverSource.protectionSource.id | Sort-Object -Unique)
    Write-Host "Protecting $servername..."
}

if($newJob -eq $True){
    $null = api post protectionJobs $job
}else{
    $null = api put protectionJobs/$($job.id) $job 
}


