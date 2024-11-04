# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][array]$jobName,
    [Parameter()][string]$jobList,
    [Parameter()][switch]$commit,
    [Parameter()][switch]$skipHostsWithExcludes
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authentication =============================================
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
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

Write-Host "Getting protection groups..."
$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&environments=kPhysical&includeTenants=true"
$jobs.protectionGroups = $jobs.protectionGroups | Where-Object {$_.physicalParams.protectionType -eq 'kFile'}

if($jobs.protectionGroups.Count -eq 0){
    Write-Host "No physical file-based jobs found"
    exit
}

if($jobNames.Count -gt 0){
    $notfoundJobs = $jobNames | Where-Object {$_ -notin $jobs.protectionGroups.name}
    if($notfoundJobs){
        Write-Host "Jobs not found $($notfoundJobs -join ', ')" -ForegroundColor Yellow
        exit 1
    }
}

$cluster = api get cluster
$outFileName = join-path -Path $PSScriptRoot -ChildPath "updateWindowsAllDrives-$($cluster.name).csv"
"""Job Name"",""Tenant"",""ObjectName"",""Include Path"",""Exclude Paths""" | Out-File -FilePath $outfileName

$jobsToUpdate = @()

Write-Host ""

foreach($job in $jobs.protectionGroups | Sort-Object -Property name){
    $updateJob = $false
    if($jobNames.Count -eq 0 -or $job.name -in $jobNames){
        if($job.permissions.Count -gt 0 -and $job.permissions[0].PSObject.Properties['name']){
            $tenant = $job.permissions[0].name
            Write-Host "$($job.name) ($tenant)"
            impersonate $tenant
        }else{
            $tenant = ""
            Write-Host "$($job.name)"
            switchback
        }
        foreach($object in $job.physicalParams.fileProtectionTypeParams.objects){
            $updateObject = $false
            $source = api get protectionSources/objects/$($object.id)
            try{
                $sourceType = $source.physicalProtectionSource.hostType
            }catch{
                $sourceType = $null
            }
            if($sourceType -eq 'kWindows'){
                $includePaths = @($object.filePaths.includedPath)
                if($includePaths.Count -eq 1 -and $includePaths[0] -eq '/c/' -and ($object.filePaths[0].excludedPaths -eq $null -or $skipHostsWithExcludes -ne $True)){
                    if($object.filePaths[0].excludedPaths -ne $null){
                        $excludedPaths = $object.filePaths[0].excludedPaths -join "; "
                    }else{
                        $excludedPaths = ''
                    }
                    $updateObject = $True
                    if($commit -eq $True){
                        Write-Host "    updating $($object.name)"
                    }else{
                        Write-Host "    would update $($object.name)"
                    }
                    $object.filePaths[0].includedPath = '$ALL_LOCAL_DRIVES'
                    $updateJob = $True
                    """$($job.name)"",""$tenant"",""$($object.name)"",""$($includePaths[0])"",""$excludedPaths""" | Out-File -FilePath $outfileName -Append
                }
            }
        }
        if($updateJob -eq $True){
            $jobsToUpdate = @($jobsToUpdate + $($job.name))
        }
        if($updateJob -eq $True -and $commit -eq $True){
            $result = api put -v2 data-protect/protection-groups/$($job.id) $job
        }
    }
}

if($commit -ne $True -and $jobsToUpdate.Count -gt 0){
    Write-Host "`nThe following jobs would be updated:`n"
    Write-Host $($jobsToUpdate -join "`n")
}

Write-Host "`nOutput saved to $outfileName`n"
