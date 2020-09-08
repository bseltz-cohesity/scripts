[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$controllerName
)

"Connecting to $controllerName..."
$null = Connect-NaController -Name $controllerName

"Exporting Shares and ACLs..."
Get-NaCifsShare | ConvertTo-Json -Depth 99 | Out-File "$controllerName-shares.json"
Get-NaCifsShareAcl | ConvertTo-Json -Depth 99 | Out-File "$controllername-acls.json"
