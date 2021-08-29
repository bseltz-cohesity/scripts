### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,            # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,       # username (local or AD)
    [Parameter()][string]$domain = 'local',
    [Parameter()][switch]$set,
    [Parameter()][switch]$clear,
    [Parameter()][string]$import = '',
    [Parameter()][string]$servicename = $null,
    [Parameter()][string]$flagname = $null,
    [Parameter()][string]$flagvalue = $null,
    [Parameter()][string]$reason = $null,
    [Parameter()][switch]$restart
)

### source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

### authenticate
apiauth -vip $vip -username $username -domain $domain

$cluster = api get cluster

function setGflag($servicename, $flagname, $flagvalue, $reason){
    $gflagReq = @{
        'clusterId' = $cluster.id;
        'gflags' = @(
            @{
                'name' = $flagname;
                'reason' = $reason;
                'value' = $flagvalue
            }
        );
        'serviceName' = $servicename;
    }
    if($clear){
        $gflagReq['clear'] = $True
    }
    $null = api post '/nexus/cluster/update_gflags' $gflagReq
}

$restartServices = @()

# set a gflag
if($set){
    if($servicename -and $flagname -and $flagvalue -and $reason){
        setGflag -servicename $servicename -flagname $flagname -flagvalue $flagvalue -reason $reason
        $restartServices += $servicename
    }else{
        Write-Host "-servicename, -flagname, -flagvalue and -reason are all required to set a gflag" -ForegroundColor Yellow
        exit
    }
}

# import list og gflags
if($import -ne ''){
    if (!(Test-Path -Path $import)) {
        Write-Host "import file $import not found" -ForegroundColor Yellow
        exit
    }else{
        $imports = Import-Csv -Path $import
        foreach($i in $imports){
            
            $serviceame = $null
            $flagname = $null
            $flagvalue = $null
            $reason = $null

            $servicename = $i.serviceName
            $flagname = $i.flagName
            $flagvalue = $i.flagValue
            $reason = $i.reason

            "setting $servicename / $flagname : $flagvalue ($reason)`n"
            if($servicename -and $flagname -and $flagvalue -and $reason){
                setGflag -servicename $servicename -flagname $flagname -flagvalue $flagvalue -reason $reason
                $restartServices += $servicename
            }else{
                Write-Host "-servicename, -flagname, -flagvalue and -reason are all required to set a gflag" -ForegroundColor Yellow
                exit
            }
        }
    }
}

# show currently set gflags
$gflaglist = @()

$gflags = (api get /nexus/cluster/list_gflags).servicesGflags

foreach($service in $gflags){
    $svcName = $service.serviceName
    $serviceGflags = $service.gflags

    Write-Host "`n$($svcName):"

    foreach($serviceGflag in $serviceGflags){
        Write-Host "    $($serviceGflag.name): $($serviceGflag.value) ($($serviceGflag.reason))"
        $gflaglist += """$svcName"",""$($serviceGflag.name)"",""$($serviceGflag.value)"",""$($serviceGflag.reason)"""
    }
}

"serviceName,flagName,flagValue,reason" | Out-File -FilePath "gflags-$($cluster.name).csv"
$gflaglist | Out-File -FilePath "gflags-$($cluster.name).csv" -Append

Write-Host "`n$($cluster.name) gflags saved to gflags-$($cluster.name).csv`n"

if($restart){
    Write-Host "Restarting required services..."
    $restartParams = @{
        "clusterId" = $cluster.id;
        "services" = @($restartServices)
    }
    $null = api post /nexus/cluster/restart $restartParams
}