### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$serverList,
    [Parameter()][array]$serverName
)

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

$servers = @(gatherList -Param $serverName -FilePath $serverList -Name 'servers' -Required $True)

Function Restart-Service([string]$strCompName,[string]$strServiceName){
    $filter = 'Name=' + "'" + $strServiceName + "'" + ''
    $service = Get-WMIObject -ComputerName $strCompName -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
    $service.StopService()
    while ($service.Started){
      Start-Sleep 2
      $service = Get-WMIObject -ComputerName $strCompName -Authentication PacketPrivacy -namespace "root\cimv2" -class Win32_Service -Filter $filter
    }
    $service.StartService()
}

foreach ($server in $servers){
    $server = $server.ToString()
    Write-Host "managing Cohesity Agent on $server"
    Write-Host "    Clearing cluster identity settings"
    $null = Invoke-Command -Computername $server -ScriptBlock {
        $null = Remove-ItemProperty -Path "HKLM:\SOFTWARE\Cohesity\Agent" -Name 'cluster_vec_registry' -ErrorAction SilentlyContinue
        $null = Remove-ItemProperty -Path "HKLM:\SOFTWARE\Cohesity\Agent" -Name 'agent_id' -ErrorAction SilentlyContinue
        $null = Remove-ItemProperty -Path "HKLM:\SOFTWARE\Cohesity\Agent" -Name 'agent_incarnation_id' -ErrorAction SilentlyContinue
        $null = Remove-ItemProperty -Path "HKLM:\SOFTWARE\Cohesity\Agent" -Name 'agent_uid' -ErrorAction SilentlyContinue
        $null = Remove-Item -Path "C:\ProgramData\Cohesity\Cert\server_cert" -ErrorAction SilentlyContinue
    }
    Write-Host "    Restarting Cohesity Agent"
    $null = Restart-Service $server 'CohesityAgent'
}
