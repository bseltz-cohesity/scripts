# usage: ./recoverNasList.ps1 -vip mycluster -username admin -nasList .\nasList.txt

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip, #the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, #username (local or AD)
    [Parameter()][string]$domain = 'local', #local or AD domain
    [Parameter()][string]$nasList = './naslist.txt'
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# get input file
$nasListFile = Get-Content $nasList

foreach($shareName in $nasListFile){

    # find nas share to recover
    $shares = api get restore/objects?search=$shareName
    $exactShares = $shares.objectSnapshotInfo | Where-Object {$_.snapshottedSource.name -ieq $shareName}

    if(! $exactShares){
        write-host "Can't find $shareName - skipping..." -ForegroundColor Yellow
    }else{

        $newViewName = $shareName.replace('\\','').replace('\','_')

        # select latest snapshot to recover
        $latestsnapshot = ($exactShares | sort-object -property @{Expression={$_.versions[0].snapshotTimestampUsecs}; Ascending = $False})[0]

        # new view parameters
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
            "viewName" = $newViewName;
            "restoreViewParameters" = @{
                "qos" = @{
                    "principalName" = "TestAndDev High"
                }
            }
        }

        "Recovering $shareName as view $newViewName"

        # perform the recovery
        $result = api post restore/recover $nasRecovery

        if($result){

            # set post recovery view settings
            do {
                $newView = (api get views).views | Where-Object { $_.name -eq $newViewName }
                sleep 1
            } until ($newView)
            
            $newView | setApiProperty -name enableSmbViewDiscovery -value $True
            $newView | setApiProperty -name enableSmbAccessBasedEnumeration -value $True
            $newView | setApiProperty -name protocolAccess -value 'kSMBOnly'
            $newView.qos = @{
                "principalName" = 'TestAndDev High';
            }
            $null = api put views $newView
        }
    }
}
