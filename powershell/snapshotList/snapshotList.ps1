### usage: ./snapshotList.ps1 -vip mycluster -username myusername [ -domain mydomain.net ] [ -olderThan 30 ] [ -sorted ]

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][int]$olderThan = 0,
    [Parameter()][switch]$sorted
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

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
