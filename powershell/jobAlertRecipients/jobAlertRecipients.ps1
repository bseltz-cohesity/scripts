### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][array]$addAddress,
    [Parameter()][array]$removeAddress
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
"Modifying email recipients:"
$jobs = api get protectionJobs | Where-Object {$_.isDeleted -ne $true -and $_.isActive -ne $false}
foreach($job in $jobs | Where-Object {$_.policyId.split(":")[0] -eq $cluster.id} | Sort-Object -Property name){
    "  $($job.name)"
    $jobEdited = $False
    if($job.PSObject.Properties['alertingConfig']){
        foreach($address in $removeAddress){
            if($address -in $job.alertingConfig.emailAddresses){
                $job.alertingConfig.emailAddresses = @($job.alertingConfig.emailAddresses | Where-Object {$_ -ne $address})
                $job.alertingConfig.emailDeliveryTargets = @($job.alertingConfig.emailDeliveryTargets | Where-Object {$_.emailAddress -ne $address})
                $jobEdited = $True
            }
        }
    }else{
        setApiProperty -object $job -name alertingConfig -value @{'emailAddresses' = @(); 'emailDeliveryTargets' = @()}
    }
    foreach($address in $addAddress){
        $address = [string]$address
        if(!($address -in $job.alertingConfig.emailAddresses)){
            $job.alertingConfig.emailAddresses = $job.alertingConfig.emailAddresses + $address
            $job.alertingConfig.emailDeliveryTargets = $job.alertingConfig.emailDeliveryTargets + @{
                "emailAddress"  = $address;
                "locale"        = "en-us";
                "recipientType" = "kTo"
            }
            $jobEdited = $True
        }
    }
    if($jobEdited -eq $True){
        $null = api put protectionJobs/$($job.id) $job
    }
}
