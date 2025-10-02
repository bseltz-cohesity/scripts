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
    [Parameter()][string]$FilePath,
    [Parameter()][string]$smbUsername,
    [Parameter()][string]$matchPath,
    [Parameter()][int]$pageCount = 1000
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
    $fileOpens = api get "smbFileOpens?viewName=$viewName&filePath=$filePath&pageCount=$pageCount"
}else{
    $fileOpens = api get "smbFileOpens?viewName=$viewName&pageCount=$pageCount"
}

if(! $fileOpens.PSObject.Properties['activeFilePaths']){
    Write-Host "No file opens"
    exit
}

$fileCount = 0
while($True){
    foreach($activeFilePath in $fileOpens.activeFilePaths){
        # $activeFilePath | toJson
        $filePath = $activeFilePath.filePath
        if(!$matchPath -or ($filePath -match $matchPath)){
            foreach($session in $activeFilePath.activeSessions){
                $thisUser = "$($session.domain)\$($session.username)"
                if(!$smbUsername -or ($thisUser -eq $smbUsername)){
                    Write-Host "Closing $filePath ($thisUser)"
                    foreach($openId in $session.activeOpens.openId){
                        $null = api post smbFileOpens @{
                            "filePath" = $filePath;
                            "openId" = $openId;
                            "viewName" = $viewName
                        }
                        $fileCount += 1
                    }
                }
            }
        }
    }
    if($fileOpens.PSObject.Properties['cookie']){
        if($viewNames.Count -eq 1){
            $fileOpens = api get "smbFileOpens?viewName=$viewName&filePath=$filePath&pageCount=$pageCount&cookie=$($fileOpens.cookie)"
        }else{
            $fileOpens = api get "smbFileOpens?viewName=$viewName&pageCount=$pageCount&cookie=$($fileOpens.cookie)"
        }
    }else{
        break
    }
}

if($fileCount -eq 0){
    Write-Host "No matching file opens"
}
