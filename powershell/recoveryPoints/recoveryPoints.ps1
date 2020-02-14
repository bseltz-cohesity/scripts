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
"JobName,JobType,ProtectedObject,RecoveryDate,ExpiryDate,RunURL" | Out-File -FilePath $outfileName

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
        "{0}({1}) {2}" -f $jobName, $objType, $objName
        $doc.versions | ForEach-Object {  
            $version = $_          
            $version.replicaInfo.replicaVec | ForEach-Object {
                if($_.target.type -eq 1){
                    $runId = $version.instanceId.jobInstanceId
                    $startTime = $version.instanceId.jobStartTimeUsecs
                    $run = api get "protectionRuns?startedTimeUsecs=$startTime&jobId=$jobId"
                    $localRun = $run.copyRun | Where-Object {$_.target.type -eq 'kLocal'}
                    $expiryTimeUsecs = $localRun.expiryTimeUsecs
                    $runURL = "https://$vip/protection/job/$jobId/run/$runId/$startTime/protection"
                    "`tRunDate: {0}`tExpiryDate: {1}" -f $(usecsToDate $startTime), $(usecsToDate $expiryTimeUsecs)
                    "$jobName,$objType,$objName,$(usecsToDate $startTime), $(usecsToDate $expiryTimeUsecs), $runURL" | Out-File -FilePath $outfileName -Append    
                }
            }
        }
    }
    "Report Saved to $outFileName"
}




