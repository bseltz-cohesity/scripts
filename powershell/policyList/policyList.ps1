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
    [Parameter()][switch]$helios,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName
)

# source the cohesity-api helper code
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

$cluster = api get cluster
$outFile = "$($cluster.name)-policyList.txt"

# get policies
$policies = api get protectionPolicies | Sort-Object -Property name

# get jobs
$jobs = api get protectionJobs

foreach($policy in $policies){
    $theseJobs = $jobs | Where-Object {$_.policyId -eq $policy.id} | Sort-Object -Property name
    $policy | Add-Member -MemberType NoteProperty -Name 'Policy Name' -Value $policy.name
    $policy | Add-Member -MemberType NoteProperty -Name 'Protection Jobs' -Value $(
        if($theseJobs){
            $theseJobs.name -join "`n"
        }else{
            '-'
        }
    )
    $policy | Add-Member -MemberType NoteProperty -Name 'DataLock Mode' -Value $(
        if($policy.wormRetentionType){
            $policy.wormRetentionType.subString(1)
        }else{
            '-'
        }
    )
    $policy | Add-Member -MemberType NoteProperty -Name 'Base Retention' -Value "$($policy.DaysToKeep) Days"
    $policy | Add-Member -MemberType NoteProperty -Name 'Replication Targets' -Value $(
        $policy.snapshotReplicationCopyPolicies.target.clusterName -join "`n"
    )
    $policy | Add-Member -MemberType NoteProperty -Name 'Archive Targets' -Value $(
        $policy.snapshotArchivalCopyPolicies.target.vaultName -join "`n"
    )
}

$policies | Format-List -Property 'Policy Name',
                                  'Base Retention',
                                  'DataLock Mode',
                                  'Replication Targets',
                                  'Archive Targets',
                                  'Protection Jobs' | Tee-Object -FilePath $outFile
