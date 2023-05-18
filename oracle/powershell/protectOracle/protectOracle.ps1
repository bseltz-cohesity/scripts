# usage: ./protectOracle.ps1 -vip mycluster -username myusername -jobName 'My Job' -servername server.mydomain.net -dbname db1

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter(Mandatory = $True)][string]$jobname,
    [Parameter()][array]$servername,
    [Parameter()][string]$serverlist,
    [Parameter()][array]$dbName,
    [Parameter()][string]$dbList,
    [Parameter()][int]$channels,
    [Parameter()][string]$channelNode,
    [Parameter()][int]$channelPort = 1521,
    [Parameter()][int]$deleteLogDays = 0,
    [Parameter()][string]$policyname,
    [Parameter()][string]$startTime = '20:00', # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone = 'America/Los_Angeles', # e.g. 'America/New_York'
    [Parameter()][int]$incrementalProtectionSlaTimeMins = 60,
    [Parameter()][int]$fullProtectionSlaTimeMins = 120,
    [Parameter()][string]$storageDomainName = 'DefaultStorageDomain', #storage domain you want the new job to write to
    [Parameter()][switch]$paused

)

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$serverNames = @(gatherList -Param $servername -FilePath $serverlist -Name 'servers' -Required $True)
$dbNames = @(gatherList -Param $dbName -FilePath $dbList -Name 'jobs' -Required $false)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# get Oracle sources
$sources = api get protectionSources?environments=kOracle

# get the protectionJob
$job = (api get -v2 data-protect/protection-groups).protectionGroups | Where-Object name -eq $jobName
$newJob = $false

if(! $job){
    # create new job
    Write-Host "Creating job $jobName..."
    $newJob = $True

    if($paused){
        $isPaused = $True
    }else{
        $isPaused = $false
    }

    # get policy
    if(! $policyname){
        Write-Host "-policyname required when creating a new job" -ForegroundColor Yellow
        exit 1
    }
    $policy = (api get -v2 "data-protect/policies").policies | Where-Object name -eq $policyName
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
        "name" = $jobName;
        "environment" = "kOracle";
        "isPaused" = $isPaused;
        "policyId" = $policy.id;
        "priority" = "kMedium";
        "storageDomainId" = $viewBox.id;
        "description" = "";
        "startTime" = @{
            "hour" = [int]$hour;
            "minute" = [int]$minute;
            "timeZone" = $timeZone
        };
        "abortInBlackouts" = $false;
        "alertPolicy" = @{
            "backupRunStatus" = @(
                "kFailure"
            );
            "alertTargets" = @()
        };
        "sla" = @(
            @{
                "backupRunType" = "kFull";
                "slaMinutes" = $fullProtectionSlaTimeMins
            };
            @{
                "backupRunType" = "kIncremental";
                "slaMinutes" = $incrementalProtectionSlaTimeMins
            }
        );
        "qosPolicy" = "kBackupAll";
        "oracleParams" = @{
            "persistMountpoints" = $true;
            "objects" = @()
        }
    }
}else{
    Write-Host "Updating job $jobname..."
}

$serversAdded = $false

foreach($servername in $serverNames){
    $foundServer = $false
    # find server to add to job
    $server = $sources.nodes | Where-Object {$_.protectionSource.name -eq $servername}
    if(!$server){
        Write-Warning "Server $servername not found!"
    }else{
        $serverId = $server.protectionSource.id
        $thisObject = $job.oracleParams.objects | Where-Object {$_.sourceId -eq $serverId}
        $job.oracleParams.objects = @($job.oracleParams.objects | Where-Object {$_.sourceId -ne $serverId})
        if(! $thisObject){
            $thisObject = @{
                "sourceId" = $serverId;
                "dbParams" = @()
            }
        }
        foreach($dbNode in $server.applicationNodes){
            if($dbNames.Count -eq 0 -or $dbNode.protectionSource.name -in $dbNames){
                Write-Host "Adding $($dbNode.protectionSource.name) to $jobName"
                $thisDB = $thisObject.dbParams | Where-Object {$_.databaseId -eq $dbNode.protectionSource.id}
                $thisObject.dbParams = @($thisObject.dbParams | Where-Object {$_.databaseId -ne $dbNode.protectionSource.id})
                if(!$thisDB){
                    $thisDB = @{
                        "databaseId" = $dbNode.protectionSource.id;
                        "dbChannels" = @()
                    }
                }
                if(($channels -and $channelNode) -or $deleteLogDays -gt 0){
                    $thisDB.dbChannels = @(
                        @{
                            "databaseUuid" = $dbNode.protectionSource.oracleProtectionSource.uuid;
                            "databaseNodeList" = @();
                            "enableDgPrimaryBackup" = $true;
                            "rmanBackupType" = "kImageCopy"
                        }
                    )
                    if($deleteLogDays -gt 0){
                        $thisDB.dbChannels[0]['archiveLogRetentionDays'] = $deleteLogDays
                    }
                    if($channels -and $channelNode){
                        $channelNodeObject = $sources.nodes | Where-Object {$_.protectionSource.name -eq $channelNode}
                        if(!$channelNodeObject){
                            Write-Host "Channel node $channelNode not found" -ForegroundColor Yellow
                            exit
                        }else{
                            $channelNodeId = $channelNodeObject.protectionSource.physicalProtectionSource.agents.id
                        }
                        $thisDB.dbChannels[0].databaseNodeList = @(
                            @{
                                "hostId" = [string]$channelNodeId;
                                "channelCount" = $channels;
                                "port" = $channelPort
                            }
                        )
                    }
                }
                $thisObject.dbParams = @($thisObject.dbParams + $thisDB)
            }
        }
        $job.oracleParams.objects = @($job.oracleParams.objects + $thisObject)
    }
}
# $job | ConvertTo-Json -Depth 99

if($newJob -eq $True){
    $null = api post -v2 data-protect/protection-groups $job
}else{
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}
