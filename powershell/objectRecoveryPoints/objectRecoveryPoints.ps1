### usage: ./objectRecoveryPoints.ps1 -vip mycluster -username myusername -domain mydomain.net -objectname *

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$objectname
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

$now = dateToUsecs (get-date)

### search for object
$search = api get "/searchvms?vmName=$objectname"


if(! $search.psobject.properties['vms']){
    write-host "No objects found with name $objectname" -ForegroundColor Yellow
    exit
}

$search.vms = $search.vms | Where-Object {$_.vmDocument.objectName -eq $objectname -or $objectName -in $_.vmDocument.objectAliases}

"{0,-22} {1,-22} {2,-22} {3,-22} {4}" -f 'ObjectName', 'JobName', 'StartTime', 'ExpiryTime', 'DaysToExpiration'  

foreach($vm in $search.vms){
    ''
    $jobName = $vm.vmDocument.jobName
    $displayName = $vm.vmDocument.objectName
    foreach($version in $vm.vmDocument.versions){
        $startTime = usecsToDate $version.instanceId.jobStartTimeUsecs
        $expiryTime = usecsToDate $version.replicaInfo.replicaVec[0].expiryTimeUsecs
        $daysToExpire = [math]::Round(($version.replicaInfo.replicaVec[0].expiryTimeUsecs- $now)/(1000000*60*60*24))
        "{0,-22} {1,-22} {2,-22} {3,-22} {4}" -f $displayName, $jobName, $startTime, $expiryTime, $daysToExpire
    }
}

