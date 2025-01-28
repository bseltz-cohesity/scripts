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
    [Parameter()][array]$jobName,
    [Parameter()][array]$jobList,
    [Parameter()][string]$jobType,
    [Parameter()][array]$addAddress,
    [Parameter()][array]$removeAddress,
    [Parameter()][switch]$alertOnSLA
)

$runStatus = @('kFailure')
if($alertOnSLA){
    $runStatus = @('kFailure', 'kSlaViolation')
}

### source the cohesity-api helper code
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

function gatherList($paramName, $textFileName=$null){
    $returnItems = @()
    foreach($item in $paramName){
        $returnItems += $item
    }
    if ($textFileName){
        if(Test-Path -FilePath $textFileName -PathType Leaf){
            $items = Get-Content $textFileName
            foreach($item in $items){
                $returnItems += [string]$item
            }
        }else{
            Write-Host "Text file $textFileName not found!" -ForegroundColor Yellow
            exit
        }
    }
    return $returnItems
}

$jobNames = gatherList $jobName $jobList

'' | Out-File -FilePath alertRecipients.txt

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"
foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        if(!$jobType -or $job.environment.substring(1) -eq $jobType){
            "`n$($job.name) ($($job.environment.substring(1)))" | Tee-Object -FilePath alertRecipients.txt -Append
            $jobEdited = $False
            if($job.PSObject.Properties['alertPolicy']){
                foreach($address in $removeAddress){
                    if($address -in $job.alertPolicy.alertTargets.emailAddress){
                        $job.alertPolicy.alertTargets = @($job.alertPolicy.alertTargets | Where-Object {$_.emailAddress -ne $address})
                        $jobEdited = $True
                    }
                }
                if($alertOnSLA){
                    if('kSlaViolation' -notin $job.alertPolicy.backupRunStatus){
                        $job.alertPolicy.backupRunStatus = @($runStatus)
                        $jobEdited = $True
                    }
                }
            }else{
                setApiProperty -object $job -name alertPolicy -value @{"backupRunStatus" = @($runStatus); "alertTargets" = @()}
            }
            foreach($address in $addAddress){
                $address = [string]$address
                if(!($address -in $job.alertPolicy.alertTargets.emailAddress)){
                    $job.alertPolicy.alertTargets = @($job.alertPolicy.alertTargets + @{
                        "emailAddress"  = $address;
                        "locale"        = "en-us";
                        "recipientType" = "kTo"
                    })
                    $jobEdited = $True
                }
            }
            foreach($address in $job.alertPolicy.alertTargets.emailAddress | Sort-Object){
                "    $address" | Tee-Object -FilePath alertRecipients.txt -Append
            }
            if($jobEdited -eq $True){
                $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
            }
        }
    }
}
