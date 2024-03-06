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
    [Parameter()][string]$clusterName,
    [Parameter()][switch]$clear,                       # switch to clear a gflag
    [Parameter()][string]$import = '',                 # import from an export file
    [Parameter()][string]$servicename = $null,         # service name to set gflag
    [Parameter()][string]$flagname = $null,            # flag name to set gflag
    [Parameter()][string]$flagvalue = $null,           # flag value to set gflag
    [Parameter()][string]$reason = $null,              # reason to set gflag
    [Parameter()][switch]$effectiveNow,                # switch to set glfag effective now
    [Parameter()][switch]$restart                      # switch restart services
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)
# authentication =============================================
# demand clusterName for Helios/MCM
if(($vip -eq 'helios.cohesity.com' -or $mcm) -and ! $clusterName){
    Write-Host "-clusterName required when connecting to Helios/MCM" -ForegroundColor Yellow
    exit 1
}

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -regionid $region -tenant $tenant -noPromptForPassword $noPrompt

# exit on failed authentication
if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# select helios/mcm managed cluster
if($USING_HELIOS){
    $thisCluster = heliosCluster $clusterName
    if(! $thisCluster){
        exit 1
    }
}
# end authentication =========================================

$cluster = api get cluster


function setGflag($servicename, $flagname, $reason, $flagvalue=$null){
    if($clear){
        write-host "clearing  $($servicename):  $flagname"
        $gflag = @{
            'gflags' = @(
                @{
                    'name' = $flagname;
                    'reason' = $reason;
                    'clear' = $true
                }
            );
            'serviceName' = $servicename;
            'effectiveNow' = $false
        }
    }else{
        write-host "setting  $($servicename):  $flagname = $flagvalue"
        $gflag = @{
            'gflags' = @(
                @{
                    'name' = $flagname;
                    'reason' = $reason;
                    'value' = $flagvalue
                }
            );
            'serviceName' = $servicename;
            'effectiveNow' = $false
        }
    }
    if($effectiveNow){
        $gflag.effectiveNow = $True
    }
    $null = api put '/clusters/gflag' $gflag
    sleep 1
}

$restartServices = @()

# set a gflag
if($flagname){
    if(!$servicename){
        Write-Host "-servicename required" -ForegroundColor Yellow
        exit
    }
    if($clear -or ($flagvalue -and $reason)){
        setGflag -servicename $servicename -flagname $flagname -flagvalue $flagvalue -reason $reason
        $restartServices += $servicename.Substring(1).ToLower()
    }else{
        Write-Host "-servicename, -flagname, -flagvalue and -reason are all required to set a gflag" -ForegroundColor Yellow
        exit
    }
}

# import list of gflags
if($import -ne ''){
    if (!(Test-Path -Path $import)) {
        Write-Host "import file $import not found" -ForegroundColor Yellow
        exit
    }else{
        $imports = Import-Csv -Path $import -Encoding utf8
        foreach($i in $imports){
            $servicename = $null
            $flagname = $null
            $flagvalue = $null
            $reason = $null

            $servicename = $i.serviceName
            $flagname = $i.flagName
            $flagvalue = $i.flagValue
            $reason = $i.reason

            if($servicename -and $flagname -and $flagvalue -and $reason){
                setGflag -servicename $servicename -flagname $flagname -flagvalue $flagvalue -reason $reason
                $restartServices += $servicename.Substring(1).ToLower()
            }else{
                Write-Host "-servicename, -flagname, -flagvalue and -reason are all required to set a gflag" -ForegroundColor Yellow
                exit
            }
        }
    }
    exit 0
}

# show currently set gflags
$gflaglist = @()

$gflags = api get /clusters/gflag

foreach($service in $gflags){
    $svcName = $service.serviceName
    $serviceGflags = $service.gflags

    Write-Host "`n$($svcName):"

    foreach($serviceGflag in $serviceGflags){
        $timeStamp = ''
        if($serviceGflag.timestamp -ne 0){
            $timeStamp = $(usecsToDate ($serviceGflag.timestamp * 1000000)).ToString('yyyy-MM-dd')
        }
        Write-Host "    $($serviceGflag.name): $($serviceGflag.value) ($($serviceGflag.reason)) ($timeStamp)"
        $gflaglist += @{'serviceName' = $svcName; 'flagName' = $serviceGflag.name; 'flagValue' = $serviceGflag.value; 'reason' = $serviceGflag.reason; 'timestamp' = $timeStamp}
    }
}

$gflaglist = ($gflaglist | ConvertTo-Json -Depth 99 | ConvertFrom-Json)
$gflaglist | Export-Csv -Path "gflags-$($cluster.name).csv" -Encoding utf8 -NoTypeInformation

Write-Host "`n$($cluster.name) gflags saved to gflags-$($cluster.name).csv`n"

if($restart){
    Write-Host "Restarting required services..."
    $restartParams = @{
        "clusterId" = $cluster.id;
        "services" = @($restartServices)
    }
    $null = api post /nexus/cluster/restart $restartParams
}
