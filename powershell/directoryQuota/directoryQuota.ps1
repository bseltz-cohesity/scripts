### usage: ./directoryQuota.ps1 -vip mycluster `
#                               -username myusername `
#                               -domain mydomain.net `
#                               -viewName myview `
#                               -path /mydir `
#                               -quotaLimitGiB 20 `
#                               -quotaAlertGiB 18

### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter(ValueFromPipeline = $true)][array]$path,
    [Parameter()][string]$pathList,
    [Parameter()][int64]$quotaLimitGiB,
    [Parameter()][int64]$quotaAlertGiB
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# validate view name
$view = (api get views).views | Where-Object name -eq $viewName

if(! $view){
    Write-Host "View $viewName not found" -ForegroundColor Yellow
    exit 1
}

# convert to Bytes
$quotaLimitBytes = $quotaLimitGiB * 1024 * 1024 * 1024
if(!$quotaAlertGiB){
    $quotaAlertGiB = $quotaLimitGiB * 0.9
}
$quotaAlertBytes = $quotaAlertGiB * 1024 * 1024 * 1024

# gather file names
$paths = @()
if($pathList -and (Test-Path $pathList -PathType Leaf)){
    $paths += Get-Content $pathList | Where-Object {$_ -ne ''}
}elseif($pathList){
    Write-Warning "File $pathList not found!"
    exit 1
}
if($path){
    $paths += $path
}
if($paths.Length -eq 0){
    # show existing quotas
    $quotas = api get "viewDirectoryQuotas?viewName=$viewName"
    if(! $quotas.quotas){
        Write-Host "No quotas found"
    }
    $pLimitGiB = @{l='Limit(GiB)';e={[math]::Round($_.policy.hardLimitBytes / (1024 * 1024 * 1024),2)}}  
    $pAlertGiB = @{l='Alert(GiB)';e={if($_.policy.alertLimitBytes){
        [math]::Round($_.policy.alertLimitBytes / (1024 * 1024 * 1024),2)}else{
            ""
        }}}
    $pDirPath = @{l='Directory'; e={$_.dirPath}}
    $pUsageGiB = @{l='Usage(GiB)'; e={[math]::Round($_.usageBytes / (1024 * 1024 * 1024),2)}}
    $quotas.quotas | Select-Object -Property $pDirPath, $pUsageGiB, $pLimitGiB, $pAlertGiB
}

foreach($dirpath in $paths){
    if($dirpath -is [System.IO.DirectoryInfo]){
        $dirpath = $dirpath.Name
    }
    $dirpath = [string]$dirpath
    if($dirpath[0] -ne '/'){
        $dirpath = "/$dirpath"
    }
    # set new quota parameters
    $quotaParams = @{
        "viewName" = $viewName;
        "quota"    = @{
            "dirPath" = $dirpath;
            "policy"  = @{
                "hardLimitBytes"  = $quotaLimitBytes;
                "alertLimitBytes" = $quotaAlertBytes
            }
        }
    }

    # put new quota
    Write-Host "Setting directory quota on $viewName$dirpath to $quotaLimitGiB GiB..."
    $null = api put viewDirectoryQuotas $quotaParams
}


