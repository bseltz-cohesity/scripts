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
    [Parameter(Mandatory = $True)][string]$viewName,
    [Parameter()][string]$FilePath
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

if($filePath){
    $fileOpens = api get "smbFileOpens?viewName=$viewName&filePath=$filePath"
}else{
    $fileOpens = api get "smbFileOpens?viewName=$viewName"
}

if(! $fileOpens.PSObject.Properties['activeFilePaths']){
    Write-Host "No file opens"
}else{
    foreach($activeFilePath in $fileOpens.activeFilePaths){
        $filePath = $activeFilePath.filePath
        Write-Host "Closing $filePath"
        foreach($openId in $activeFilePath.activeSessions.activeOpens.openId){
            $null = api post smbFileOpens @{
                "filePath" = $filePath;
                "openId" = $openId;
                "viewName" = $viewName
            }
        }
    }
}
