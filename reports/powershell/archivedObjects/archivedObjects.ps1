[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local'
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster
$clusterName = $cluster.name

$dateString = (get-date).ToString("yyyy-MM-dd")
$outfileName = "$clusterName-ArchivedObjects-$dateString.csv"

"Job Name,Job Type,Protected Object,Latest Backup Date,Latest Archive Date,Archive Target,ArchiveExpiry" | Out-File -FilePath $outfileName

### find recoverable objects
$ro = api get /searchvms

$environments = @('Unknown', 'VMware', 'HyperV', 'SQL', 'View',
                  'RemoteAdapter', 'Physical', 'Pure', 'Azure', 'Netapp',
                  'Agent', 'GenericNas', 'Acropolis', 'PhysicalFiles',
                  'Isilon', 'KVM', 'AWS', 'Exchange', 'HyperVVSS',
                  'Oracle', 'GCP', 'FlashBlade', 'AWSNative', 'VCD',
                  'O365', 'O365Outlook', 'HyperFlex', 'GCPNative',
                  'AzureNative','AD', 'AWSSnapshotManager', 'Unknown', 
                  'Unknown', 'Unknown', 'Unknown', 'Unknown')

if($ro.count -gt 0){
    $ro.vms | Sort-Object -Property {$_.vmDocument.jobName}, {$_.vmDocument.objectName } | ForEach-Object {
        $doc = $_.vmDocument
        $jobName = $doc.jobName
        $objName = $doc.objectName
        $objType = $environments[$doc.registeredSource.type]
        $objAlias = ''
        if('objectAliases' -in $doc.PSobject.Properties.Name){
            $objAlias = $doc.objectAliases[0]
            if($objAlias -eq "$objName.vmx" -or $objType -eq 'VMware'){
                $objAlias = ''
            }
        }
        if($objAlias -ne ''){
            $objName = "$objName on $objAlias"
        }
        $latestVersion = 0
        $latestArchiveVersion = 0
        $archiveExpiryUsecs = 0
        $vaultName = ''
        $doc.versions | ForEach-Object {  
            $version = $_
            $startTime = $version.instanceId.jobStartTimeUsecs
            if($latestVersion -eq 0){
                $latestVersion = $startTime
            }
            $version.replicaInfo.replicaVec | ForEach-Object {
                if($_.target.type -eq 3) {
                    if($latestArchiveVersion -eq 0){
                        $latestArchiveVersion = $startTime
                        $vaultName = $_.target.archivalTarget.name
                    }
                    if($archiveExpiryUsecs -eq 0){
                        $archiveExpiryUsecs = $_.expiryTimeUsecs
                    }
                }
            }
        }
        if($latestArchiveVersion -eq 0){
            $archiveVersion = ''
        }else{
            $archiveVersion = (usecsToDate $latestArchiveVersion).ToString("yyyy-MM-dd hh:mm")
        }
        if($archiveExpiryUsecs -eq 0){
            $archiveExpiry = ''
        }else{
            $archiveExpiry = (usecsToDate $archiveExpiryUsecs).ToString("yyyy-MM-dd hh:mm")
        }
        $runDate = (usecsToDate $latestVersion).ToString("yyyy-MM-dd hh:mm")
        write-host ("{0}, {1}, {2}, {3}, {4}, {5}" -f $jobName, $objType, $objName, $runDate, $archiveVersion, $vaultName)
        "$jobName,$objType,$objName,$runDate,$archiveVersion,$vaultName,$archiveExpiry" | Out-File -FilePath $outfileName -Append
    }
    write-host "`nReport Saved to $outFileName`n" -ForegroundColor Blue
}
