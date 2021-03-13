### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][array]$jobName,
    [Parameter()][array]$jobList,
    [Parameter()][string]$jobType,
    [Parameter()][array]$addAddress,
    [Parameter()][array]$removeAddress
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

function gatherList($paramName, $textFileName=$null){
    $returnItems = @()
    foreach($item in $paramName){
        $returnItems += $item
    }
    if ($textFileName){
        if(Test-Path -Path $textFileName -PathType Leaf){
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

# $cluster = api get cluster
"Modifying email recipients:"
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true"
# $jobs = api get protectionJobs | Where-Object {$_.isDeleted -ne $true -and $_.isActive -ne $false}
foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        if(!$jobType -or $job.environment.substring(1) -eq $jobType){
            "  $($job.name) ($($job.environment))"
            $jobEdited = $False
            if($job.PSObject.Properties['alertPolicy']){
                foreach($address in $removeAddress){
                    if($address -in $job.alertPolicy.alertTargets.emailAddress){
                        $job.alertPolicy.alertTargets = @($job.alertPolicy.alertTargets | Where-Object {$_.emailAddress -ne $address})
                        $jobEdited = $True
                    }
                }
            }else{
                setApiProperty -object $job -name alertPolicy -value @{"backupRunStatus" = @("kFailure"); "alertTargets" = @()}
            }
            foreach($address in $addAddress){
                $address = [string]$address
                if(!($address -in $job.alertPolicy.alertTargets.emailAddress)){
                    $job.alertPolicy.alertTargets = $job.alertPolicy.alertTargets + @{
                        "emailAddress"  = $address;
                        "locale"        = "en-us";
                        "recipientType" = "kTo"
                    }
                    $jobEdited = $True
                }
            }
            if($jobEdited -eq $True){
                $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
            }
        }
    }
}
