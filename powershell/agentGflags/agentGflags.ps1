### process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$serverList, #Servers to add as physical source
    [Parameter()][array]$serverName,
    [Parameter()][switch]$clear,
    [Parameter()][string]$flagName,
    [Parameter()][string]$flagValue,
    [Parameter()][switch]$restart
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

$serverNames = @(gatherList -Param $serverName -FilePath $serverList -Name 'servers' -Required $True)

foreach ($server in $serverNames){
    $server = $server.ToString()
    "$server"
    if($clear){
        if(! $flagName){
            Write-Host "-flagName is required" -ForegroundColor Yellow
            exit
        }
        $null = Invoke-Command -Computername $server -ArgumentList $flagName -ScriptBlock {
            param($flagName)
            Write-Host "    Clearing flag: $flagName"
            # delete registery value
            $null = Remove-ItemProperty -Path "HKLM:\SOFTWARE\Cohesity\Agent\Parameters" -Name $flagName -ErrorAction SilentlyContinue
        }
    }elseif(! $flagName){
        $null = Invoke-Command -Computername $server -ArgumentList $flagName -ScriptBlock {
            $ignoreProps = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')
            $props = Get-ItemProperty -Path "HKLM:\Software\Cohesity\Agent\Parameters"
            foreach($prop in $props.PSObject.Properties | Where-Object Name -notin $ignoreProps){
                if($($prop.Name) -notin $ignoreProps){
                    Write-Host "    $($prop.Name) : $($prop.Value)"
                }
            }
        }
    }else{
        if(! $flagValue){
            Write-Host "-flagValue is required" -ForegroundColor Yellow
            exit
        }
        $null = Invoke-Command -Computername $server -ArgumentList $flagName, $flagValue -ScriptBlock {
            param($flagName, $flagValue)
            Write-Host "    Setting flag: $flagName : $flagValue"
            # create Parameters key
            $null = New-Item -Path 'HKLM:\SOFTWARE\Cohesity\Agent' -Name 'Parameters' -ErrorAction SilentlyContinue
            # find existing entry
            $existingFlag = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Cohesity\Agent\Parameters' -Name $flagName -ErrorAction SilentlyContinue
            if(!$existingFlag){
                # create new entry
                $null = New-ItemProperty -Path 'HKLM:\SOFTWARE\Cohesity\Agent\Parameters' -Name $flagName -Value $flagValue -PropertyType "String"
            }else{
                # edit existing entry
                $null = Set-Itemproperty -path 'HKLM:\SOFTWARE\Cohesity\Agent\Parameters' -Name $flagName -value $flagValue
            }
        }
    }
    if($restart){
        Write-Host "    Restarting Cohesity Agent"
        $null = Invoke-Command -Computername $server -ScriptBlock {
            $null = Restart-Service -Name 'CohesityAgent'
        }
    }
}