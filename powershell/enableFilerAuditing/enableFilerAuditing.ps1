### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][switch]$disable
)

if($disable){
    $enable = $false
}else{
    $enable = $True
}

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -noPromptForPassword $noPrompt

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

$shares = (api get shares).sharesList
$views = api get -v2 file-services/views

foreach($share in $shares){
    $share.shareName
    $isView = $false
    if($share.shareName -eq $share.viewName){
        $isView = $True
        $thisView = $views.views | Where-Object name -eq $share.viewName
        if(! $thisView.isReadOnly){
            setApiProperty -object $thisView -name enableFilerAuditLogging -value $enable
            $null = api put -v2 file-services/views/$($thisView.viewId) $thisView
        }
    }else{
        setApiProperty -object $share -name 'aliasName' -value $share.shareName
        setApiProperty -object $share -name enableFilerAuditLog -value $enable
        $null = api put viewAliases $share
    }
}
