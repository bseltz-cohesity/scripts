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
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter(ValueFromPipeline = $true)][array]$path,
    [Parameter()][string]$pathList,
    [Parameter()][int64]$quotaLimitGiB = 0,
    [Parameter()][int64]$quotaAlertGiB = 0,
    [Parameter()][int64]$pageCount = 1000
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -sendMfaCode $emailMfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS -and !$region){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        write-host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated"
    exit 1
}

# validate view name
$view = (api get views).views | Where-Object name -eq $viewName

if(! $view){
    Write-Host "View $viewName not found" -ForegroundColor Yellow
    exit 1
}

# convert to Bytes
$quotaLimitBytes = $quotaLimitGiB * 1024 * 1024 * 1024
if($quotaAlertGiB -eq 0){
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
if($paths.Length -eq 0 -or $quotaLimitGiB -eq 0){
    # show existing quotas
    $cookie = $null
    while($True){
        if($cookie){
            $quotas = api get "viewDirectoryQuotas?viewName=$viewName&pageCount=$pageCount&cookie=$cookie"
        }else{
            $quotas = api get "viewDirectoryQuotas?viewName=$viewName&pageCount=$pageCount"
        }
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
        if($paths.Length -gt 0 -and $quotas.PSObject.Properties['quotas']){
            $quotas.quotas = $quotas.quotas | Where-Object {$_.dirPath -in $paths}
        }
        $quotas.quotas | Select-Object -Property $pDirPath, $pUsageGiB, $pLimitGiB, $pAlertGiB
        if($quotas.PSObject.Properties['cookie']){
            $cookie = $quotas.cookie
        }else{
            break
        }
    }
}

foreach($dirpath in $paths){
    if($dirpath -is [System.IO.DirectoryInfo]){
        $dirpath = $dirpath.Name
    }
    $dirpath = [string]$dirpath
    if($dirpath[0] -ne '/'){
        $dirpath = "/$dirpath"
    }
    if($quotaLimitGiB -ne 0){
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
}


