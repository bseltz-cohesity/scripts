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
    [Parameter()][array]$viewName,
    [Parameter()][string]$viewList,
    [Parameter()][string]$path,
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

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "smbFileOpens-$($cluster.name)-$dateString.csv"

# headings
"""View Name"",""Client IP"",""User"",""File Path""" | Out-File -FilePath $outfileName


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


$viewNames = @(gatherList -Param $viewName -FilePath $viewList -Name 'views' -Required $false)

if($viewNames.Count -eq 1){
    $fileOpens = api get "smbFileOpens?viewName=$($viewNames[0])&pageCount=$pageCount"
}else{
    $fileOpens = api get "smbFileOpens?pageCount=$pageCount"
}

if(! $fileOpens.PSObject.Properties['activeFilePaths']){
    Write-Host "No file opens"
}
while($True){
    foreach($filePath in $fileOpens.activeFilePaths){
        if($viewNames.Count -eq 0 -or $filePath.viewName -in $viewNames){
            foreach($session in $filePath.activeSessions){
                if(! $path -or $filePath.filePath -match $path){
                    """{0}"",""{1}"",""{2}\{3}"",""{4}""" -f $filePath.viewName, $session.clientIP, $session.domain, $session.username, $filePath.filePath | Tee-Object -FilePath $outfileName -Append
                }            
            }
        }
    }
    if($fileOpens.PSObject.Properties['cookie']){
        Write-Host "found cookie"
        if($viewNames.Count -eq 1){
            $fileOpens = api get "smbFileOpens?viewName=$($viewNames[0])&pageCount=$pageCount&cookie=$($fileOpens.cookie)"
        }else{
            $fileOpens = api get "smbFileOpens?pageCount=$pageCount&cookie=$($fileOpens.cookie)"
        }
    }else{
        break
    }
}


"`nOutput saved to $outfilename`n"
