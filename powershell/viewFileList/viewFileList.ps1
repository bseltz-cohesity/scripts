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
    [Parameter()][string]$clusterName = $null,
    [Parameter(Mandatory=$True)][string]$viewName,
    [Parameter()][switch]$noIndex,
    [Parameter()][int]$depth = 0,
    [Parameter()][switch]$showFiles,
    [Parameter()][ValidateSet('MiB','GiB')][string]$unit = 'MiB'
)

$conversion = @{'Kib' = 1024; 'MiB' = 1024 * 1024; 'GiB' = 1024 * 1024 * 1024; 'TiB' = 1024 * 1024 * 1024 * 1024}
function toUnits($val){
    return "{0:n0}" -f ($val/($conversion[$unit]))
}

if($noIndex){
    $useLibrarian = $False
}else{
    $useLibrarian = $True
}

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

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

$views = api get -v2 file-services/views
$view = $views.views | Where-Object name -eq $viewName
if(!$view){
    Write-Host "$viewName not found" -ForegroundColor Yellow
    exit
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "fileList-$($cluster.name)-$($view.name)-$dateString.csv"

# headings
"""Path"",""Type"",""Size ($unit)"",""Last Modified""" | Out-File -FilePath $outfileName

$currentDepth = 1

function listdir($thisView, $dirPath, $thisDepth){
    $thisDepth += 1
    $thisDirPath = [System.Web.HttpUtility]::UrlEncode($dirPath).Replace('%2f%2f','%2F')
    $entries = api get "/vm/directoryList?statFileEntries=true&useLibrarian=$($useLibrarian)&dirPath=$thisDirPath&viewName=$($view.name)&viewBoxId=$($view.storageDomainId)"
    foreach($entry in $entries.entries){
        if($entry.type -eq 'kDirectory' -or $showFiles){
            Write-Host "$($entry.fullPath) ($(usecsToDate $entry.fstatInfo.mtimeUsecs))"
            """$($entry.fullPath)"",""$($entry.type.subString(1))"",""$(toUnits $entry.fstatInfo.size)"",""$(usecsToDate $entry.fstatInfo.mtimeUsecs)""" | Out-File -FilePath $outfileName -Append
        }
        if($entry.type -eq 'kDirectory'){
            if($depth -eq 0 -or $thisDepth -le $depth){
                listdir $thisView $entry.fullPath $($thisDepth)
            }
        }
    }
}

listdir $view '/' $currentDepth

"`nOutput saved to $outfilename`n"
