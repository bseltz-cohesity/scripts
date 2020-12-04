# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter(Mandatory = $True)][string]$jobName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$groups = api get "data-protect/protection-groups?isDeleted=false&includeTenants=true&includeLastRunInfo=true" -v2
$group = $groups.protectionGroups | Where-Object {$_.name -eq 'utils'}
if($group){
    if($group.lastRun.localBackupInfo.status -eq 'SucceededWithWarning'){
        $run = api get "data-protect/protection-groups/$($group.id)/runs/$($group.lastRun.id)?includeObjectDetails=true" -v2
        if($run){
            foreach($obj in $run.objects){
                $objName = $obj.object.name
                $objId = $obj.object.id
                if($obj.localSnapshotInfo.snapshotInfo.PSObject.Properties['warnings']){
                    $thisFile = "$($group.name)-" + $objName.replace("\","-").replace("/","-").replace(":","-") + "-warnings.txt"
                    write-host "Downloading warnings for $objName to $thisFile"
                    fileDownload -v2 -uri "data-protect/protection-groups/$($group.id)/runs/$($group.lastRun.id)/objects/$objId/downloadMessages" -fileName $thisFile
                }
            }
        }
    }
}
