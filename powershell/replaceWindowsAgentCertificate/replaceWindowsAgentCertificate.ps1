### process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$serverName,
    [Parameter()][string]$certFile
)

if(!$certFile){
    $certFile = "server_cert-$($serverName)"
}

Write-Host "  renaming C:\ProgramData\Cohesity\Cert\server_cert -> C:\ProgramData\Cohesity\Cert\server_cert-orig"
$null = Invoke-Command -Computername $serverName -ScriptBlock {
    $null = Rename-Item -Path "C:\ProgramData\Cohesity\Cert\server_cert" -NewName "server_cert-orig" -ErrorAction SilentlyContinue
}

Write-Host "  copying $certfile -> C:\ProgramData\Cohesity\Cert\server_cert"
Copy-Item -Path $certFile -Destination \\$serverName\c$\ProgramData\Cohesity\Cert\server_cert

Write-Host "  restarting Cohesity Agent"
# $null = Restart-Service $serverName 'CohesityAgent'
$null = Invoke-Command -Computername $serverName -ScriptBlock {
    $null = Restart-Service -Name 'CohesityAgent'
}
