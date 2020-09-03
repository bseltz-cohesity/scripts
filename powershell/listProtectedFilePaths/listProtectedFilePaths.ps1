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

$sources = api get protectionSources?environments=kPhysical
$jobs = api get "protectionJobs?environments=kPhysicalFiles&environments=kPhysical"

foreach($job in $jobs){
    "`n{0}" -f $job.name
    $jobSources = $job.sourceSpecialParameters
    foreach($source in $jobSources){
        $sourceId = $source.sourceId
        $protectionSource = $sources[0].nodes | Where-Object {$_.protectionSource.id -eq $sourceId}
        $sourceName = $protectionSource.protectionSource.name
        "`n    $sourceName"
        if($job.environment -eq 'kPhysicalFiles'){
            foreach($filePath in $source.physicalSpecialParameters.filePaths){
                "      + {0} (SkipNestedVolumes={1})" -f $filePath.backupFilePath, $filePath.skipNestedVolumes
                foreach($excludePath in $filePath.excludedFilePaths){
                    "        - {0}" -f $excludePath
                }
            }
        }else{
            if($source.physicalSpecialParameters.volumeGuid){
                foreach($volumeGuid in $source.physicalSpecialParameters.volumeGuid){
                    $volumeInfo = $protectionSource.protectionSource.physicalProtectionSource.volumes | Where-Object guid -eq $volumeGuid
                    $volumeLabel = $volumeInfo.label
                    if($volumeLabel -eq 'System Reserved'){
                        "      + System Reserved (volume)"
                    }else{
                        $volumeMountPoint = $volumeInfo.mountPoints[0]
                        "      + {0} (volume)" -f $volumeMountPoint
                    }
                }
            }else{
                "      + All Volumes"
            }
        }
    }
}
