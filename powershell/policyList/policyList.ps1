# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

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
