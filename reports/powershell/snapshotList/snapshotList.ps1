### usage: ./snapshotList.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] [ -olderThan 30 ] [ -sorted ]

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
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][int]$olderThan = 0,
    [Parameter()][switch]$sorted
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $helios -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

$report = @{}
$sortableList = @()

$objects = api get /searchvms

foreach($object in $objects.vms){
    $jobName = $object.vmDocument.jobName
    if($jobName -notin $report.Keys){
        $report[$jobName] = @{
            'versions' = @()
        }
        foreach($version in $object.vmDocument.versions){
            if($version.replicaInfo.replicaVec.target.type -eq 1){
                if($version.snapshotTimestampUsecs -lt (timeAgo $olderThan days)){
                    if($version.snapshotTimestampUsecs -notin $report[$jobName].versions){
                        $report[$jobName].versions += usecsToDate $version.snapshotTimestampUsecs
                        $sortableList += "$(usecsToDate $version.snapshotTimestampUsecs) ($jobName)"
                    }
                }
            }
        }
    }
}

if($sorted){
    foreach($item in $sortableList | Sort-Object -Descending){
        write-host $item
    }
}else{
    foreach($jobName in $report.Keys | sort){
        write-host $jobName
        foreach($version in $report[$jobName].versions){
            write-host "`t$version"
        }
    }
}