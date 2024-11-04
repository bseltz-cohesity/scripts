# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][array]$vip,
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][array]$clusterName = $null,
    [Parameter()][double]$costPerGiB = 1.0,
    [Parameter()][int]$numRuns = 500,
    [Parameter()][string]$smtpServer, #outbound smtp server '192.168.1.95'
    [Parameter()][string]$smtpPort = 25, #outbound smtp port
    [Parameter()][array]$sendTo, #send to address
    [Parameter()][string]$sendFrom #send from address
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# outfile
$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = "chargebackReport-$dateString.tsv"

# headings
$headings = "Object Name`tSource Name`tGroup Name`tPolicy Name`tObject Type`tSystem Name`tLogical GiB`tCost`tOrganization Name`tDescription"

$headings | Out-File -FilePath $outfileName

# convert to units
$unit = 'GiB'
$conversion = @{'KiB' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n2}" -f ($val/($conversion[$unit]))
}

function reportCluster(){

    $cluster = api get cluster
    $jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&includeTenants=true"
    $sources = api get "protectionSources/registrationInfo?includeApplicationsTreeInfo=false"
    $policies = api get -v2 data-protect/policies
    $seen = @{}
    foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
        $endUsecs = dateToUsecs $now
        $environment = $job.environment
        $tenant = $job.permissions.name
        if(!$objectType -or $objectType -eq $environment){
            "{0} ({1})" -f $job.name, $environment
            $policyName = ($policies.policies | Where-Object id -eq $job.policyId).name
            if(!$policyName){
                $policyName = '-'
            }
            while($True){
                $runs = api get -v2 "data-protect/protection-groups/$($job.id)/runs?numRuns=$numRuns&endTimeUsecs=$endUsecs&includeTenants=true&includeObjectDetails=true"
                foreach($run in $runs.runs){
                    $localSources = @{}
                    if(! $run.PSObject.Properties['isLocalSnapshotsDeleted']){
                        if($run.PSObject.Properties['localBackupInfo']){
                            $backupInfo = $run.localBackupInfo
                            $snapshotInfo = 'localSnapshotInfo'
                        }else{
                            $backupInfo = $run.originalBackupInfo
                            $snapshotInfo = 'originalBackupInfo'
                        }
                        $runType = $backupInfo.runType
                        if($includeLogs -or $runType -ne 'kLog'){
                            $runStartTime = usecsToDate $backupInfo.startTimeUsecs
                            if($days -and $daysBack -gt $runStartTime){
                                break
                            }
                            if($backupInfo.isSlaViolated){
                                $slaStatus = 'Missed'
                            }else{
                                $slaStatus = 'Met'
                            }
                            "    {0} ({1})" -f $runStartTime, $runType
                            foreach($object in $run.objects){
                                if($environment -in @('kOracle', 'kSQL') -and $object.object.objectType -eq 'kHost'){
                                    $localSources["$($object.object.id)"] = $object.object.name
                                }
                            }
                            foreach($object in $run.objects){
                                $objectName = $object.object.name
                                if($environment -notin @('kOracle', 'kSQL') -or ($environment -in @('kOracle', 'kSQL') -and $object.object.objectType -ne 'kHost')){
                                    if($object.object.PSObject.Properties['sourceId']){
                                        if($environment -in @('kOracle', 'kSQL')){
                                            $registeredSourceName = $localSources["$($object.object.sourceId)"]
                                        }else{
                                            $registeredSource = $sources.rootNodes | Where-Object {$_.rootNode.id -eq $object.object.sourceId}
                                            $registeredSourceName = $registeredSource.rootNode.name
                                        }
                                        if(!$registeredSourceName){
                                            $registeredSourceName = $objectName
                                        }
                                    }else{
                                        $registeredSourceName = $objectName
                                    }
                                    $objectStatus = $object.$snapshotInfo.snapshotInfo.status
                                    if($objectStatus -eq 'kSuccessful'){
                                        $objectStatus = 'kSuccess'
                                    }
                                    $objectLogicalSizeBytes = toUnits $object.$snapshotInfo.snapshotInfo.stats.logicalSizeBytes
                                    "        {0}" -f $objectName
                                    $keyName = "{0}{1}" -f $objectName, $registeredSourceName
                                    if(! $seen[$keyName]){
                                        $cost = "{0:C}" -f ($costPerGiB * $objectLogicalSizeBytes)
                                        $objectName, $registeredSourceName, $job.name, $policyName, $environment, $cluster.name, $objectLogicalSizeBytes, $cost, $tenant, $job.description -join "`t" | Out-File -FilePath $outfileName -Append
                                        $seen[$keyName] = 1
                                    }
                                }
                            }
                        }
                    }
                }
                if($runs.runs.Count -eq $numRuns){
                    if($runs.runs[-1].PSObject.Properties['localBackupInfo']){
                        $endUsecs = $runs.runs[-1].localBackupInfo.endTimeUsecs - 1
                    }else{
                        $endUsecs = $runs.runs[-1].originalBackupInfo.endTimeUsecs - 1
                    }
                    if($endUsecs -lt 0 -or $endUsecs -lt $daysBackUsecs){
                        break
                    }
                }else{
                    break
                }
            }
        }
    }
}

# authentication =============================================
if(! $vip){
    $vip = @('helios.cohesity.com')
}

foreach($v in $vip){
    # authenticate
    apiauth -vip $v -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt -quiet
    if(!$cohesity_api.authorized){
        output "`n$($v): authentication failed" -ForegroundColor Yellow
        continue
    }
    if($USING_HELIOS){
        if(! $clusterName){
            $clusterName = @((heliosClusters).name)
        }
        foreach($c in $clusterName){
            $null = heliosCluster $c
            reportCluster
        }
    }else{
        reportCluster
    }
}

"`nOutput saved to $outfilename`n"

if($smtpServer -and $sendTo -and $sendFrom){
    Write-Host "`nsending report to $([string]::Join(", ", $sendTo))`n"

    # send email report
    foreach($toaddr in $sendTo){
        Send-MailMessage -From $sendFrom -To $toaddr -SmtpServer $smtpServer -Port $smtpPort -Subject "Chargeback Report" -Attachments $outfileName -WarningAction SilentlyContinue
    }
}
