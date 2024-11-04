### process commandline arguments
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
    [Parameter()][string]$policyName,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][string]$newName,
    [Parameter()][string]$startTime, # e.g. 23:30 for 11:30 PM
    [Parameter()][string]$timeZone, # e.g. 'America/New_York'
    [Parameter()][int]$incrementalProtectionSlaTimeMins,
    [Parameter()][int]$fullProtectionSlaTimeMins,
    [Parameter()][ValidateSet('None','kSuccess','kSlaViolation','kFailure')][array]$alertOn,
    [Parameter()][array]$addRecipient,
    [Parameter()][array]$removeRecipient,
    [Parameter()][switch]$disableIndexing,
    [Parameter()][switch]$enableIndexing,
    [Parameter()][array]$indexPath,
    [Parameter()][string]$indexList,
    [Parameter()][switch]$addIncludePath,
    [Parameter()][switch]$addExcludePath,
    [Parameter()][switch]$removeIncludePath,
    [Parameter()][switch]$removeExcludePath,
    [Parameter()][switch]$clearExcludePaths
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

# find job params path
function findObjectParam($o){
    $jobParams = $o.PSObject.Properties.Name -match 'params'
    foreach($param in $jobParams){
        if($o.$param.PSObject.Properties['objects']){
            $objectParam = $o.$param
        }elseif($o.$param.PSObject.Properties.Name -match 'params'){
            $objectParam = findObjectParam $o.$param
        }
    }
    return $objectParam
}

function findIndexingPolicy($o){
    $jobParams = $o.PSObject.Properties
    foreach($param in $jobParams){
        if($param.Name -eq 'indexingPolicy'){
            $indexParam = $o.$($param.Name)
        }elseif($param.TypeNameOfValue -eq 'System.Management.Automation.PSCustomObject'){
            $indexParam = findIndexingPolicy $o.$($param.Name)
        }
    }
    return $indexParam
}

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

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $True)
$indexPaths = @(gatherList -Param $indexPath -FilePath $indexList -Name 'index paths' -Required $False)

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
    }
}

if($newName -and $jobNames.Count -gt 1){
    Write-Host "-newName can only operate on one job, exiting" -ForegroundColor Yellow
    exit 1
}

# parse startTime
if($startTime){
    $hour, $minute = $startTime.split(':')
    $tempInt = ''
    if(! (($hour -and $minute) -or ([int]::TryParse($hour,[ref]$tempInt) -and [int]::TryParse($minute,[ref]$tempInt)))){
        Write-Host "Please provide a valid start time" -ForegroundColor Yellow
        exit 1
    }
}

# get policy ID
if($policyName){
    $policies = (api get -v2 data-protect/policies).policies
    $newPolicy = $policies | Where-Object { $_.name -ieq $policyName }
    if(!$newPolicy){
        Write-Warning "Policy $policyName not found!"
        exit 1
    }
}

# default indexing policy
$defaultIndexingPolicy = @{
    "enableIndexing" = $true;
    "includePaths" = @(
        "/"
    );
    "excludePaths" = @(
        '/$Recycle.Bin';
        "/Windows";
        "/Program Files";
        "/Program Files (x86)";
        "/ProgramData";
        "/System Volume Information";
        "/Users/*/AppData";
        "/Recovery";
        "/var";
        "/usr";
        "/sys";
        "/proc";
        "/lib";
        "/grub";
        "/grub2";
        "/opt";
        "/splunk"
    )
}

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $updateJob = $false
    if($job.name -in $jobNames){
        Write-Host "$($job.name)"
        if($newName){
            $job.name = $newName
            Write-Host "    renaming to $newName"
            $updateJob = $True
        }
        $jobParams = findObjectParam $job
        $isCAD = $jobParams.directCloudArchive
        # update policy
        if($policyName){
            $updatePolicy = $True
            if($isCAD){
                $existingPolicy = $policies | Where-Object id -eq $job.policyId
                # validate same vault ID
                $existingVaultId = $existingPolicy.remoteTargetPolicy.archivalTargets[0].targetId
                if($True -eq $updatePolicy -and $newPolicy.PSObject.Properties['remoteTargetPolicy'] -and $newPolicy.remoteTargetPolicy.PSObject.Properties['archivalTargets'] -and $newPolicy.remoteTargetPolicy.archivalTargets.Count -eq 1){
                    $newVaultId = $newPolicy.remoteTargetPolicy.archivalTargets[0].targetId
                    if($newVaultId -ne $existingVaultId){
                        $updatePolicy = $false
                        Write-Host "    can't update policy - archival targets do not match" -ForegroundColor Yellow
                    }
                    # validate archive schedule
                    if($True -eq $updatePolicy -and $newPolicy.remoteTargetPolicy.archivalTargets[0].schedule.unit -ne 'Runs'){
                        $updatePolicy = $false
                        Write-Host "    can't update policy - archive must run after every run" -ForegroundColor Yellow
                    }
                }else{
                    $updatePolicy = $false
                    Write-Host "    can't update policy - archival targets do not match" -ForegroundColor Yellow
                }
                # validate no replication
                if($True -eq $updatePolicy -and $newPolicy.PSObject.Properties['remoteTargetPolicy'] -and $newPolicy.remoteTargetPolicy.PSObject.Properties['replicationTargets'] -and $newPolicy.remoteTargetPolicy.replicationTargets.Count -gt 0){
                    $updatePolicy = $false
                    Write-Host "    can't update policy - replication not allowed for CAD policies" -ForegroundColor Yellow
                }
                # validate no retries
                if($True -eq $updatePolicy -and $newPolicy.retryOptions.retries -gt 0){
                    $updatePolicy = $false
                    Write-Host "    can't update policy - num retries must be zero for CAD policies" -ForegroundColor Yellow
                }
            }
            if($True -eq $updatePolicy){
                Write-Host "    updating policy"
                $updateJob = $True
                $job.policyId = $newPolicy.id
            }            
        }
        # update starttime
        if($startTime){
            Write-Host "    updating start time"
            $updateJob = $True
            $job.startTime.hour = [int]$hour
            $job.startTime.minute = [int]$minute
        }
        # update timezone
        if($timeZone){
            Write-Host "    updating timezone"
            $updateJob = $True
            $job.startTime.timeZone = $timeZone
        }
        # update SLAs
        if($incrementalProtectionSlaTimeMins){
            Write-Host "    updating SLA (incremental)"
            $updateJob = $True
            $incrementalSLA = $job.sla | Where-Object backupRunType -eq 'kIncremental'
            $incrementalSLA.slaMinutes = [int]$incrementalProtectionSlaTimeMins
        }
        if($fullProtectionSlaTimeMins){
            Write-Host "    updating SLA (full)"
            $updateJob = $True
            $fullSLA = $job.sla | Where-Object backupRunType -eq 'kFull'
            $fullSLA.slaMinutes = [int]$fullProtectionSlaTimeMins
        }
        # update alerts
        if($alertOn){
            Write-Host "    updating alerts"
            $updateJob = $True
            if("None" -in $alertOn){
                if($job.PSObject.Properties['alertPolicy']){
                    delApiProperty -object $job -name 'alertPolicy'
                }
            }else{
                if(!$job.PSObject.Properties['alertPolicy']){
                    setApiProperty -object $job -name 'alertPolicy' -value @{
                        "backupRunStatus" = @($alertOn);
                        "alertTargets" = @()
                    }
                }else{
                    $job.alertPolicy.backupRunStatus = @($alertOn)
                }
            }
        }
        # add alert recipients
        if($addRecipient.Count -gt 0){
            Write-Host "    updating alerts"
            if($job.PSObject.Properties['alertPolicy']){
                foreach($address in $addRecipient){
                    $address = [string]$address
                    if(!($address -in $job.alertPolicy.alertTargets.emailAddress)){
                        $job.alertPolicy.alertTargets = @($job.alertPolicy.alertTargets + @{
                            "emailAddress"  = $address;
                            "locale"        = "en-us";
                            "recipientType" = "kTo"
                        })
                        $updateJob = $True
                    }
                }
            }
        }
        # remove alert recipients
        if($removeRecipient.Count -gt 0){
            Write-Host "    updating alerts"
            if($job.PSObject.Properties['alertPolicy']){
                foreach($address in $removeRecipient){
                    if($address -in $job.alertPolicy.alertTargets.emailAddress){
                        $job.alertPolicy.alertTargets = @($job.alertPolicy.alertTargets | Where-Object {$_.emailAddress -ne $address})
                        $updateJob = $True
                    }
                }
            }
        }
        # enable indexing
        if($enableIndexing){
            Write-Host "    updating indexing"
            $indexingPolicy = findIndexingPolicy $job
            if($indexingPolicy){
                if($indexingPolicy.enableIndexing -eq $false){
                    $indexingPolicy.enableIndexing = $True
                    $indexingPolicy.includePaths = $defaultIndexingPolicy.includePaths
                    $indexingPolicy.excludePaths = $defaultIndexingPolicy.excludePaths
                    $updateJob = $True
                }
            }
        }
        # disable indexing
        if($disableIndexing){
            Write-Host "    updating indexing"
            $indexingPolicy = findIndexingPolicy $job
            if($indexingPolicy){
                if($indexingPolicy.enableIndexing -eq $True){
                    $indexingPolicy.enableIndexing = $false
                    $indexingPolicy.includePaths = $null
                    $indexingPolicy.excludePaths = $null
                    $updateJob = $True
                }
            }
        }
        # add indexing include paths
        if($addIncludePath -or $addExcludePath -or $removeExcludePath -or $removeIncludePath -or $clearExcludePaths){
            Write-Host "    updating indexing"
            $indexingPolicy = findIndexingPolicy $job
            if($indexingPolicy){
                if($indexingPolicy.enableIndexing -eq $True){
                    if($clearExcludePaths){
                        $indexingPolicy.excludePaths = $null
                    }
                    if($addIncludePath){
                        foreach($ip in $indexPaths){
                            $indexingPolicy.includePaths = @($indexingPolicy.includePaths + $ip)
                        }
                    }
                    if($removeIncludePath -and $indexingPolicy.includePaths -ne $null){
                        $indexingPolicy.includePaths = @($indexingPolicy.includePaths | Where-Object {$_ -notin $indexPaths})
                    }
                    if($addExcludePath){
                        if($indexingPolicy.excludePaths -eq $null){
                            $indexingPolicy.excludePaths = @()
                        }
                        foreach($ip in $indexPaths){
                            $indexingPolicy.excludePaths = @($indexingPolicy.excludePaths + $ip)
                        }
                    }
                    if($removeExcludePath -and $indexingPolicy.excludePaths -ne $null){
                        $indexingPolicy.excludePaths = @($indexingPolicy.excludePaths | Where-Object {$_ -notin $indexPaths})
                    }
                    if($indexingPolicy.includePaths -eq $null -or $indexingPolicy.includePaths.Count -eq 0){
                        $indexingPolicy.enableIndexing = $false
                        $indexingPolicy.includePaths = $null
                        $indexingPolicy.excludePaths = $null
                    }
                    if($indexingPolicy.excludePaths -eq $null -or $indexingPolicy.excludePaths.Count -eq 0){
                        $indexingPolicy.excludePaths = $null
                    }
                    $updateJob = $True
                }
            }
        }
    }
    if($True -eq $updateJob){
        $null = api put -v2 data-protect/protection-groups/$($job.id) $job
    }
}
