# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][array]$policyName,
    [Parameter()][string]$policyList,
    [Parameter()][int64]$lockDuration = 5,
    [Parameter()][switch]$asAdmin,
    [Parameter()][switch]$disable
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

# outfile
$cluster = api get cluster
if($cluster.clusterSoftwareVersion -lt '6.6'){
    Write-Host "This script requires Cohesity 6.6 or later" -ForegroundColor Yellow
    exit
}

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

if($asAdmin){
    # create temp DS User
    $nowMsecs = [int64]((dateToUsecs $now) / 1000)
    $dsUsername = "ds-$($nowMsecs)"

    $tempUserParams = @{
        "domain" = "LOCAL";
        "effectiveTimeMsecs" = $nowNsecs;
        "roles" = @(
            "COHESITY_DATA_SECURITY"
        );
        "restricted" = $false;
        "type" = "user";
        "_isDeletable" = $true;
        "_principalType" = "local_user";
        "username" = $dsUsername;
        "password" = 'Gaj1$iteeHoka!2xz';
        "emailAddress" = "$dsUsername@$($cluster.domainNames[0])";
        "passwordConfirm" = 'Gaj1$iteeHoka!2xz';
        "additionalGroupNames" = @()
    }

    $tempUser = api post users $tempUserParams

    # create temp API key
    $newKeyParams = @{
        "isActive" = $true;
        "user" = $tempUser;
        "name" = "$($tempUser.username)-key";
        "expiringTimeMsecs" = $null
    }

    $newKey = api post users/$($tempUser.sid)/apiKeys/ $newKeyParams 
    $apiKey = $newKey.key

    apiauth -vip $vip -username $($tempUser.username) -domain 'local' -useApiKey -password $apiKey -quiet
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
        }elseif($disable){
            $policyChanged = $True
            delApiProperty -object $policy.backupPolicy.regular.retention -name 'dataLockConfig'
        }
        foreach($extendedRetention in $policy.extendedRetention){
            if(! $extendedRetention.retention.PSObject.Properties['dataLockConfig']){
                $policyChanged = $True
                setApiProperty -object $extendedRetention.retention -name 'dataLockConfig' -value @{
                    "mode" = "Compliance";
                    "unit" = "Days";
                    "duration" = $lockDuration
                }
            }elseif($disable){
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
                    }elseif($disable){
                        $policyChanged = $True
                        delApiProperty -object $replicationTarget.retention -name 'dataLockConfig'
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
                    }elseif($disable){
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

if($asAdmin){
    # authenticate
    if($useApiKey){
        apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password -quiet
    }else{
        apiauth -vip $vip -username $username -domain $domain -password $password -quiet
    }

    $deleteUserParams = @{
        "domain" = "LOCAL";
        "users" = @(
            "$($tempUser.username)"
        )
    }

    $null = api delete users $deleteUserParams
}

"`nOutput saved to $outfilename`n"
