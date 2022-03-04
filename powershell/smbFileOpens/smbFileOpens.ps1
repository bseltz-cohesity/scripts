# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][array]$viewName,
    [Parameter()][string]$viewList,
    [Parameter()][string]$password = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
if($useApiKey){
    apiauth -vip $vip -username $username -domain $domain -useApiKey -password $password
}else{
    apiauth -vip $vip -username $username -domain $domain -password $password
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

$fileOpens = api get smbFileOpens

foreach($filePath in $fileOpens.activeFilePaths){
    if($viewNames.Count -eq 0 -or $filePath.viewName -in $viewNames){
        foreach($session in $filePath.activeSessions){
            """{0}"",""{1}"",""{2}\{3}"",""{4}""" -f $filePath.viewName, $session.clientIP, $session.domain, $session.username, $filePath.filePath | Tee-Object -FilePath $outfileName -Append
        }
    }
}

"`nOutput saved to $outfilename`n"
