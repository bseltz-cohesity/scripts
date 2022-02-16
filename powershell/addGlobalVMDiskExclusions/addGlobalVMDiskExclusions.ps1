### usage: ./protectVMs.ps1 -vip bseltzve01 -username admin -jobName 'vm backup' -vmName mongodb

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter(Mandatory = $True)][string]$jobName,  # name of the job to add VM to
    [Parameter()][array]$excludeDisk,
    [Parameter()][string]$excludeList,
    [Parameter()][switch]$replace
)

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

$exclusions = @(gatherList -Param $excludeDisk -FilePath $excludeList -Name 'exclusions' -Required $false)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
}

$controllerType = @{'SCSI' = 'kScsi'; 'IDE' = 'kIde'; 'SATA' = 'kSata'}

# validate exclude disks
foreach($exclusion in $exclusions){
    $exclusionValid = $false
    $parts = $exclusion -split ':'
    if($parts.Count -eq 3){
        if($parts[0] -in @('SCSI', 'IDE', 'SATA')){
            if($parts[1] -match '([0-9]|[0-9][0-9])'){
                if($parts[2] -match '([0-9]|[0-9][0-9])'){
                    $exclusionValid = $True
                }else{
                    Write-Host "$exclusion <- bus number is invalid" -ForegroundColor Yellow
                    exit
                }
            }else{
                Write-Host "$exclusion <- unit number is invalid" -ForegroundColor Yellow
                exit
            }
        }else{
            Write-Host "$exclusion <- controller type is invalid (must be SCSI, IDE or SATA)" -ForegroundColor Yellow
            exit
        }
    }
    if(!$exclusionValid){
        Write-Host "$exclusion <- is invalid"
        exit
    }
}

# get the protectionJob
$job = (api get -v2 "data-protect/protection-groups").protectionGroups | Where-Object {$_.name -eq $jobName}

if($job){
    if(!$job.vmwareParams.PSObject.Properties['globalExcludeDisks']){
        setApiProperty -object $job -name 'globalExcludeDisks' -value @()
    }
    if($replace){
        $job.vmwareParams.globalExcludeDisks = @()
    }
    foreach($exclusion in $exclusions){
        $ctype, $busNum, $unitNum = $exclusion -split ':'
        $thisControllerType = $controllerType[$ctype]
        "Adding exclusion $exclusion"
        $existingExclusion = $job.vmwareParams.globalExcludeDisks | Where-Object {$_.controllerType -eq $thisControllerType -and $_.busNumber -eq $busNum -and $_.unitNumber -eq $unitNum}
        if(!$existingExclusion){
            $newExclusion = @{
                "controllerType" = $thisControllerType;
                "busNumber" = [int64]$busNum;
                "unitNumber" = [int64]$unitNum
            }
            $job.vmwareParams.globalExcludeDisks = @($job.vmwareParams.globalExcludeDisks + $newExclusion)
        }
    }
    "Updating protection group '$jobName'"
    $null = api put -v2 "data-protect/protection-groups/$($job.id)" $job
}else{
    Write-Host "Protection group '$jobName' not found" -ForegroundColor Yellow
    exit
}
