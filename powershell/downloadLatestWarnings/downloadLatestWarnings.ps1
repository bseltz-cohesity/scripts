# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip='helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

# gather list from command line params and file
function gatherList($Param=$null, $FilePath=$null, $Required=$True, $Name='items'){
    $items = @()
    if($Param){
        $Param | ForEach-Object {$items += $_}
    }
    if($FilePath){
        if(Test-Path -Path $FilePath -PathType Leaf){
            Get-Content $FilePath | ForEach-Object {$items += [string]$_}
        }else{
            Write-Host "Text file $FilePath not found!" -ForegroundColor Yellow
            exit
        }
    }
    if($Required -eq $True -and $items.Count -eq 0){
        Write-Host "No $Name specified" -ForegroundColor Yellow
        exit
    }
    return ($items | Sort-Object -Unique)
}

$jobNames = @(gatherList -Param $jobName -FilePath $jobList -Name 'jobs' -Required $false)

$groups = api get "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&includeLastRunInfo=true" -v2

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $groups.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found: $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
    $groups.protectionGroups = $groups.protectionGroups | Where-Object {$_.name -in $jobNames}
}

foreach($group in $groups.protectionGroups | Sort-Object -Property name){
    if($group.lastRun.localBackupInfo.status -eq 'SucceededWithWarning'){
        Write-Host $group.name
        $run = api get "data-protect/protection-groups/$($group.id)/runs/$($group.lastRun.id)?includeObjectDetails=true&includeTenants=true" -v2
        if($run){
            foreach($obj in $run.objects){
                $objName = $obj.object.name
                $objId = $obj.object.id
                if($obj.localSnapshotInfo.snapshotInfo.PSObject.Properties['warnings'] -and $obj.localSnapshotInfo.snapshotInfo.warnings.Count -gt 0){
                    $thisFile = "$($group.name)-" + $objName.replace("\","-").replace("/","-").replace(":","-").replace(" ","-") + "-warnings.csv"
                    Write-Host "    $objName -> $thisFile"
                    $result = fileDownload -v2 -uri "data-protect/protection-groups/$($group.id)/runs/$($group.lastRun.id)/objects/$objId/downloadMessages" -fileName $thisFile -quiet
                    if($cohesity_api.last_api_error -ne 'OK'){
                        "Warning" | Out-File -FilePath $thisFile
                        foreach($warning in $obj.localSnapshotInfo.snapshotInfo.warnings){
                            $warning | Out-File -FilePath $thisFile -Append
                        }
                    }
                }
            }
        }
    }
}
