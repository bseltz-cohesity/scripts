# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,
    [Parameter(Mandatory = $True)][string]$username,
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$sqlFile = ".\query.sql",
    [Parameter()][string]$outFile = ".\grootExport.csv"
)

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -tenant $tenant

$postgres = api get postgres

$MyServer = $postgres[0].nodeIp
$MyPort  = $postgres[0].port
$MyDB = "postgres"
$MyUid = $postgres[0].defaultUsername
$MyPass = $postgres[0].defaultPassword

$DBConnectionString = "Driver={PostgreSQL UNICODE(x64)};Server=$MyServer;Port=$MyPort;Database=$MyDB;Uid=$MyUid;Pwd=$MyPass;"
$DBConn = New-Object System.Data.Odbc.OdbcConnection;
$DBConn.ConnectionString = $DBConnectionString;
$DBConn.Open();
$DBCmd = $DBConn.CreateCommand();

if(! (Test-Path -Path $sqlFile)){
    Write-Host "SQL file $sqlFile not found" -ForegroundColor Yellow
    exit
}else{
    Write-Host "Executing SQL Query..."
}

$DBCmd.CommandText = Get-Content -Path $sqlFile
$ds = New-Object system.Data.DataSet
(New-Object system.Data.odbc.odbcDataAdapter($DBCmd)).fill($ds) | out-null

Write-Host "Outputting to $outFile"
$ds.Tables[0] | Export-Csv -Path $outFile -NoTypeInformation

$DBConn.Close();
