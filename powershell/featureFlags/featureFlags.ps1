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
    [Parameter()][string]$flagName,
    [Parameter()][string]$reason,
    [Parameter()][switch]$isUiFeature,
    [Parameter()][switch]$clear,
    [Parameter()][string]$importFile = $null
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

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

# outfile
$cluster = api get cluster
$outfileName = "featureFlags-$($cluster.name).csv"

# headings
"FlagName,isUiFeature,isApproved,Reason,Timestamp" | Out-File -FilePath $outfileName -Encoding utf8
Write-Host ""

$timestamp = [Int64]((dateToUsecs) / 1000000)

function setFeatureFlag($flagname, $reason, $ui=$false){
    if($ui -eq $False){
        $uiFeature = $False
    }else{
        $uiFeature = $True
    }
    
    $flag = @{
        "name" = $flagname;
        "isApproved" =  $True;
        "isUiFeature" = $uiFeature;
        "reason" = $reason;
        "clear" = $False;
        "timestamp" = $timestamp
    }

    if($clear -eq $True){
        $flag['clear'] = $True
    }else{
        if(! $reason){
            Write-Host "-reason is required to set a feature flag" -ForegroundColor Yellow
            exit
        }
    }

    if($clear -eq $True){
        Write-Host "Clearing Feature Flag $flagname"
    }else{
        Write-Host "Setting Feature Flag $flagname"
    }
    
    $response = api put -v2 clusters/feature-flag $flag
}

# set a flag
if($flagName){
    setFeatureFlag -flagname $flagName -reason $reason -ui $isuifeature
}elseif($importFile){
    # import flags fom export file
    if (!(Test-Path -Path $importFile)) {
        Write-Host "import file $importFile not found" -ForegroundColor Yellow
        exit
    }else{
        $imports = Import-Csv -Path $importFile -Encoding utf8
        foreach($f in $imports){
            if($f.isUiFeature.ToUpper() -eq 'FALSE'){
                $ui = $false
            }else{
                $ui = $True
            }
            setFeatureFlag -flagname $f.flagName -reason $f.reason -ui $ui
        }
    }
}

Write-Host "`nCurrent Feature Flags:"

$flags = api get -v2 clusters/feature-flag

foreach($flag in $flags){
    Write-Host "`n        name: $($flag.name)"
    Write-Host " isUiFeature: $($flag.isUiFeature)"
    Write-Host "  isApproved: $($flag.isApproved)"
    Write-Host "      reason: $($flag.reason)"
    Write-Host "   timestamp: $(usecsToDate ($flag.timestamp * 1000000))"
    "{0},{1},{2},{3},{4}" -f $flag.name, $flag.isUiFeature, $flag.isApproved, $flag.reason, $(usecsToDate ($flag.timestamp * 1000000)) | Out-File -FilePath $outfileName -Append
}

"`nOutput saved to $outfilename`n"
