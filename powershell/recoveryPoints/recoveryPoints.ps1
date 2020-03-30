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

$dateString = (get-date).ToString().Replace(' ','_').Replace('/','-').Replace(':','-')
$outfileName = "RecoverPoints-$dateString.csv"
"Job Name,Job Type,Protected Object,Recovery Date,Local Expiry,Remote Expiry,Archival Expiry,Run URL" | Out-File -FilePath $outfileName

### find recoverable objects
$ro = api get /searchvms

$environments = @('Unknown', 'VMware', 'HyperV', 'SQL', 'View',
                  'RemoteAdapter', 'Physical', 'Pure', 'Azure', 'Netapp',
                  'Agent', 'GenericNas', 'Acropolis', 'PhysicalFiles',
                  'Isilon', 'KVM', 'AWS', 'Exchange', 'HyperVVSS',
                  'Oracle', 'GCP', 'FlashBlade', 'AWSNative', 'VCD',
                  'O365', 'O365Outlook', 'HyperFlex', 'GCPNative',
                  'Unknown', 'Unknown', 'Unknown', 'Unknown', 'Unknown',
                  'Unknown', 'Unknown', 'Unknown') 

if($ro.count -gt 0){
    $ro.vms | Sort-Object -Property {$_.vmDocument.jobName}, {$_.vmDocument.objectName } | ForEach-Object {
        $doc = $_.vmDocument
        $jobId = $doc.objectId.jobId
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
        write-host ("`n{0} ({1}) {2}" -f $jobName, $objType, $objName) -ForegroundColor Green 
        $versionList = @()
        $doc.versions | ForEach-Object {  
            $version = $_
            $runId = $version.instanceId.jobInstanceId
            $startTime = $version.instanceId.jobStartTimeUsecs
            $local = 0
            $remote = 0
            $archive = 0

            $version.replicaInfo.replicaVec | ForEach-Object {
                if($_.target.type -eq 1){
                    $local = $_.expiryTimeUsecs
                }elseif($_.target.type -eq 2){
                    if($_.expiryTimeUsecs -gt $remote){
                        $remote = $_.expiryTimeUsecs
                    }
                }elseif($_.target.type -eq 3) {
                    if($_.expiryTimeUsecs -gt $archive){
                        $archive = $_.expiryTimeUsecs
                    }
                }
            }
            $versionList += @{'RunDate' = $startTime; 'local' = $local; 'remote' = $remote; 'archive' = $archive; 'runId' = $runId; 'startTime' = $startTime}
        }
        write-host "`n`t             RunDate           SnapExpires        ReplicaExpires        ArchiveExpires" -ForegroundColor Blue
        foreach($version in $versionList){
            if($version['local'] -eq 0){
                $local = '-'
            }else{
                $local = usecsToDate $version['local']
            }
            if($version['remote'] -eq 0){
                $remote = '-'
            }else{
                $remote = usecsToDate $version['remote']
            }
            if($version['archive'] -eq 0){
                $archive = '-'
            }else{
                $archive = usecsToDate $version['archive']
            }
            $runDate = usecsToDate $version['RunDate']
            "`t{0,20}  {1,20}  {2,20}  {3,20}" -f $runDate, $local, $remote, $archive
            
            $runURL = "https://$vip/protection/job/$jobId/run/$($version['runId'])/$($version['startTime'])/protection"
            "$jobName,$objType,$objName,$runDate,$local,$remote,$archive,$runURL" | Out-File -FilePath $outfileName -Append
        }
    }
    write-host "`nReport Saved to $outFileName`n" -ForegroundColor Blue
}




