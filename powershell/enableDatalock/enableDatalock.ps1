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
    [Parameter()][array]$policyName,
    [Parameter()][string]$policyList,
    [Parameter()][int64]$lockDuration = 5,
    [Parameter()][switch]$disable
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

# outfile
$cluster = api get cluster
$now = Get-Date
$dateString = $now.ToString('yyyy-MM-dd')
$outfileName = "log-enableDatalock-$($cluster.name)-$dateString.txt"

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

$policyNames = @(gatherList -Param $policyName -FilePath $policyList -Name 'policies' -Required $false)
$policies = api get -v2 "data-protect/policies"

if($policyNames.Count -gt 0){
    $notfoundPolicies = $policyNames | Where-Object {$_ -notin $policies.policies.name}
    if($notfoundPolicies){
        Write-Host "Policies not found $($notfoundPolicies -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

"`nProcessing policies...`n" | Tee-Object -FilePath $outfileName

foreach($policy in ($policies.policies | Sort-Object -Property name)){
    if($policyNames.Count -eq 0 -or $policy.name -in $policyNames){
        $policy.name | Tee-Object -FilePath $outfileName -Append
        $policyChanged = $false
        if(! $policy.backupPolicy.regular.retention.PSObject.Properties['dataLockConfig']){
            $policyChanged = $True
            setApiProperty -object $policy.backupPolicy.regular.retention -name 'dataLockConfig' -value @{
                "mode" = "Compliance";
                "unit" = "Days";
                "duration" = $lockDuration
            }
        }
        if($disable){
            $policyChanged = $True
            delApiProperty -object $policy.backupPolicy.regular.retention -name 'dataLockConfig'
        }
        if($policy.backupPolicy.PSObject.Properties['log']){
            if(! $policy.backupPolicy.log.retention.PSObject.Properties['dataLockConfig']){
                $policyChanged = $True
                setApiProperty -object $policy.backupPolicy.log.retention -name 'dataLockConfig' -value @{
                    "mode" = "Compliance";
                    "unit" = "Days";
                    "duration" = $lockDuration
                }
            }
            if($disable){
                $policyChanged = $True
                delApiProperty -object $policy.backupPolicy.log.retention -name 'dataLockConfig'
            }
        }
        foreach($extendedRetention in $policy.extendedRetention){
            if(! $extendedRetention.retention.PSObject.Properties['dataLockConfig']){
                $policyChanged = $True
                setApiProperty -object $extendedRetention.retention -name 'dataLockConfig' -value @{
                    "mode" = "Compliance";
                    "unit" = "Days";
                    "duration" = $lockDuration
                }
            }
            if($disable){
                $policyChanged = $True
                delApiProperty -object $extendedRetention.retention -name 'dataLockConfig'
            }
        }
        if($policy.PSObject.Properties['remoteTargetPolicy']){
            if($policy.remoteTargetPolicy.PSObject.Properties['replicationTargets']){
                foreach($replicationTarget in $policy.remoteTargetPolicy.replicationTargets){
                    if(! $replicationTarget.retention.PSObject.Properties['dataLockConfig']){
                        $policyChanged = $True
                        setApiProperty -object $replicationTarget.retention -name 'dataLockConfig' -value @{
                            "mode" = "Compliance";
                            "unit" = "Days";
                            "duration" = $lockDuration
                        }
                    }
                    if($disable){
                        $policyChanged = $True
                        delApiProperty -object $replicationTarget.retention -name 'dataLockConfig'
                    }
                    if($replicationTarget.PSObject.Properties['logRetention']){
                        if(! $replicationTarget.logRetention.PSObject.Properties['dataLockConfig']){
                            $policyChanged = $True
                            setApiProperty -object $replicationTarget.logRetention -name 'dataLockConfig' -value @{
                                "mode" = "Compliance";
                                "unit" = "Days";
                                "duration" = $lockDuration
                            }
                        }
                        if($disable){
                            $policyChanged = $True
                            delApiProperty -object $replicationTarget.logRetention -name 'dataLockConfig'
                        }
                    }
                }
            }
            if($policy.remoteTargetPolicy.PSObject.Properties['archivalTargets']){
                foreach($archivalTarget in $policy.remoteTargetPolicy.archivalTargets){
                    if(! $archivalTarget.retention.PSObject.Properties['dataLockConfig']){
                        $policyChanged = $True
                        setApiProperty -object $archivalTarget.retention -name 'dataLockConfig' -value @{
                            "mode" = "Compliance";
                            "unit" = "Days";
                            "duration" = $lockDuration
                        }
                    }
                    if($disable){
                        $policyChanged = $True
                        delApiProperty -object $archivalTarget.retention -name 'dataLockConfig'
                    }
                }
            }
        }

        if($True -eq $policyChanged){
            if($disable){
                "    removing datalock" | Tee-Object -FilePath $outfileName -Append
            }else{
                "    adding datalock" | Tee-Object -FilePath $outfileName -Append
            }
            if(! $policy.PSObject.Properties['isCBSEnabled']){
                setApiProperty -object $policy -name 'isCBSEnabled' -value $True
            }else{
                $policy.isCBSEnabled = $True
            }
            $null = api put -v2 data-protect/policies/$($policy.id) $policy
        }else{
            if($disable){
                "    not datalocked" | Tee-Object -FilePath $outfileName -Append
            }else{
                "    already datalocked" | Tee-Object -FilePath $outfileName -Append
            }
        }
    }
}

"`nOutput saved to $outfilename`n"
