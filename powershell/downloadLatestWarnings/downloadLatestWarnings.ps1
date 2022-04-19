# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$jobName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

$groups = api get "data-protect/protection-groups?isDeleted=false&includeTenants=true&includeLastRunInfo=true" -v2
if($jobName){
    $groups.protectionGroups = $groups.protectionGroups | Where-Object {$_.name -eq $jobName}
    if($groups.protectionGroups.Count -eq 0){
        Write-Host "Job $jobName not found" -foregroundcolor Yellow
    }
}

foreach($group in $groups.protectionGroups | Sort-Object -Property name){
    if($group.lastRun.localBackupInfo.status -eq 'SucceededWithWarning'){
        $group.name
        $run = api get "data-protect/protection-groups/$($group.id)/runs/$($group.lastRun.id)?includeObjectDetails=true" -v2
        if($run){
            foreach($obj in $run.objects){
                $objName = $obj.object.name
                $objId = $obj.object.id
                if($obj.localSnapshotInfo.snapshotInfo.PSObject.Properties['warnings'] -and $obj.localSnapshotInfo.snapshotInfo.warnings.Count -gt 0){
                    $thisFile = "$($group.name)-" + $objName.replace("\","-").replace("/","-").replace(":","-").replace(" ","-") + "-warnings.txt"
                    write-host "  Downloading warnings for $objName to $thisFile"
                    $result = fileDownload -v2 -uri "data-protect/protection-groups/$($group.id)/runs/$($group.lastRun.id)/objects/$objId/downloadMessages" -fileName $thisFile
                    $resultObj = $result | ConvertFrom-Json
                    if($resultObj.PSObject.Properties['errorCode']){
                        foreach($warning in $obj.localSnapshotInfo.snapshotInfo.warnings){
                            $warning | Out-File -FilePath $thisFile -Append
                        }
                    }
                }
            }
        }
    }
}
