# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$emailMfaCode,
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory=$True)][string]$oldNode,
    [Parameter(Mandatory=$True)][string]$newNode,
    [Parameter(Mandatory=$True)][string]$jobName,
    [Parameter()][string]$newJobName
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$sources = api get "protectionSources/registrationInfo?environments=kPhysical"
$newSource = $sources.rootNodes | Where-Object {$_.rootNode.name -eq $newNode}
if(! $newSource){
    Write-Host "$newNode not found" -ForegroundColor Yellow
    exit
}

$jobs = api get -v2 "data-protect/protection-groups?isDeleted=false&isActive=true&includeTenants=true&environments=kPhysical"

$job = $jobs.protectionGroups = $jobs.protectionGroups | Where-Object {$_.name -eq $jobName}

if(! $job){
    Write-Host "$job not found" -ForegroundColor Yellow
    exit
}

if($job.physicalParams.protectionType -eq 'kFile'){
    $foundOldNode = $false
    foreach($o in $job.physicalParams.fileProtectionTypeParams.objects){
        if($o.name -eq $oldNode){
            $foundOldNode = $True
            $o.name = $newSource.rootNode.name
            $o.id = $newSource.rootNode.id
            foreach($filePath in $o.filePaths){
                if($filePath.includedPath -match $oldNode){
                    $filePath.includedPath = $filePath.includedPath.replace($oldNode, $newSource.rootNode.name)
                    foreach($excludedPath in $filePath.excludedPaths){
                        if($excludedPath -match $oldNode){
                            $newExcludedPath = $excludedPath.replace($oldNode, $newSource.rootNode.name)
                            $filePath.excludedPaths = @($filePath.excludedPaths | Where-Object {$_ -ne $excludedPath}) + $newExcludedPath
                        }
                    }
                }
            }
        }
    }
    if($foundOldNode -eq $True){
        if($newJobName){
            Write-Host "Renaming $($job.name) -> $newJobName"
            $job.name = $newJobName            
        }else{
            Write-Host "Updating $($job.name)"
        }
        Write-Host "Swapping $oldNode -> $newNode"
        $null = api put -v2 data-protect/protection-groups/$($job.id) $job
    }else{
        Write-Host "$oldNode not found in $jobName"
    }
}else{
    Write-Host "$jobName is not a file-based protection group" -ForegroundColor Yellow
}
