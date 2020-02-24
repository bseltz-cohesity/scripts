### usage: ./recoverNas.ps1 -vip mycluster -username admin -shareName \\netapp1.mydomain.net\share1 -viewName share1

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter(Mandatory = $True)][string]$shareName, #sharename as listed in sources
    [Parameter(Mandatory = $True)][string]$viewName, #name of the view to create
    [Parameter()][string]$sourceName = $null
)

### source the cohesity-api helper code
. ./cohesity-api

### authenticate
apiauth -vip $vip -username $username -domain $domain

### hard coding the qos selection
$qosSetting = 'TestAndDev High'

### find the VM to recover
$shares = api get restore/objects?search=$shareName

### narrow results to VMs with the exact name
$exactShares = $shares.objectSnapshotInfo | Where-Object {$_.snapshottedSource.name -ieq $shareName} #).objectSnapshotInfo[0]

if($sourceName){
    $exactShares = $exactShares | Where-Object {$_.registeredSource.name -ieq $sourceName }
}

if(! $exactShares){
    write-host "No matches found!" -ForegroundColor Yellow
    exit
}
### if there are multiple results (e.g. old/new jobs?) select the one with the newest snapshot 
$latestsnapshot = ($exactShares | sort-object -property @{Expression={$_.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

$nasRecovery = @{
    "name" = "Recover-$shareName";
    "objects" = @(
        @{
            "jobId" = $latestsnapshot.jobId;
            "jobUid" = $latestsnapshot.jobUid;
            "jobRunId" = $latestsnapshot.versions[0].jobRunId;
            "startedTimeUsecs" = $latestsnapshot.versions[0].startedTimeUsecs;
            "protectionSourceId" = $latestsnapshot.snapshottedSource.id
        }
    );
    "type" = "kMountFileVolume";
    "viewName" = $viewName;
    "restoreViewParameters" = @{
        "qos" = @{
            "principalName" = $qosSetting
        }
    }
}

"Recovering $shareName as view $viewName"

$result = api post restore/recover $nasRecovery
if($result){
    sleep 1
    $newView = (api get views).views | Where-Object { $_.name -eq $viewName }
    $newView | setApiProperty -name enableSmbViewDiscovery -value $True
    $newView.qos = @{
        "principalName" = 'TestAndDev High';
    }
    $null = api put views $newView
}
