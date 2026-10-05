<#
.SYNOPSIS
    Calculates recommended Cohesity cluster and agent gflag settings for tuning
    EPIC Cache/IRIS (physical Linux/AIX) backup performance.

.DESCRIPTION
    Replaces the "Auto tuning Gflags for epic backups for linux_AIX physical.xlsx"
    spreadsheet. Given the same inputs the spreadsheet collected, this script
    computes the same recommended gflag values, prints them to the screen, and
    writes them - along with the exact commands to apply them - to a text file.

    Cluster-level gflags are applied with iris_cli. Agent-level gflags are applied
    with magneto_agent_debug_tool, run from an SSH session on the Cohesity cluster.
    AIX env.sh settings must be hand-edited on the mount host and the agent restarted.

.PARAMETER NodeCount
    Number of nodes in the Cohesity cluster.

.PARAMETER HostOS
    Operating system of the EPIC mount host: AIX or LINUX.

.PARAMETER NicSpeed
    NIC speed range of the mount host: 10GbE or >10GbE.

.PARAMETER CpuCores
    Number of CPU cores on the mount host (e.g. 2 x Intel Xeon 12-core = 24).

.PARAMETER AgentEndpoint
    Hostname or IP of the mount host, substituted into the agent CLI commands.
    Defaults to a placeholder you can fill in later if you don't have it handy.

.PARAMETER OutputFile
    Path to the text file the full recommendations, apply instructions, and
    ready-to-paste command/config sections are written to. Defaults to
    .\EpicGflagRecommendations.txt in the current directory.

.EXAMPLE
    .\epicGflagRecommendations.ps1 -NodeCount 19 `
        -HostOS AIX -NicSpeed 10GbE -CpuCores 20

.EXAMPLE
    .\epicGflagRecommendations.ps1 -NodeCount 8 `
        -HostOS LINUX -NicSpeed ">10GbE" -CpuCores 32 -AgentEndpoint epic-mount01.hospital.local `
        -OutputFile C:\Temp\epic01-gflags.txt

.NOTES
    Author: Brian Seltzer / Cohesity
    Ported from: Auto tuning Gflags for epic backups for linux_AIX physical.xlsx
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Number of nodes in the Cohesity cluster")]
    [ValidateRange(1, 256)]
    [int]$NodeCount,

    [Parameter(Mandatory = $true, HelpMessage = "Mount host operating system")]
    [ValidateSet("AIX", "LINUX")]
    [string]$HostOS,

    [Parameter(Mandatory = $false, HelpMessage = "Mount host NIC speed range")]
    [ValidateSet("10GbE", ">10GbE")]
    [string]$NicSpeed = ">10GbE",

    [Parameter(Mandatory = $false, HelpMessage = "Number of CPU cores on the mount host")]
    [ValidateRange(1, 1024)]
    [int]$CpuCores = 24,

    [Parameter(Mandatory = $false)]
    [string]$AgentEndpoint = "<replace with your hostname or IP>",

    [Parameter(Mandatory = $false)]
    [string]$OutputFile = ".\EpicGflagRecommendations.txt"
)

# ------------------------------------------------------------------------
# Helper: Excel's ROUND() rounds half-away-from-zero. .NET's default
# [math]::Round() uses banker's rounding (half-to-even), so this wrapper
# keeps the arithmetic identical to the original spreadsheet.
# ------------------------------------------------------------------------
function Get-ExcelRound {
    param(
        [double]$Value,
        [int]$Digits = 0
    )
    return [math]::Round($Value, $Digits, [System.MidpointRounding]::AwayFromZero)
}

# ------------------------------------------------------------------------
# Core calculations (mirrors the spreadsheet's "DO NOT EDIT" calc table)
# ------------------------------------------------------------------------
$isTenGig       = ($NicSpeed -eq "10GbE")
$agentConfigFilePath = if ($HostOS -eq "AIX") { "/etc/aix_agent_config.cfg" } else { "/etc/cohesity-agent/agent.cfg" }

$gatekeeperValue    = if ($isTenGig) { 12 } else { 16 }
$gatekeeperFlagName = if ($HostOS -eq "AIX") {
    "magneto_gatekeeper_max_tasks_per_physical_aix_entity"
} else {
    "magneto_gatekeeper_max_tasks_per_physical_linux_entity"
}

$concurrentSubTasks   = 2 * $gatekeeperValue
$subTaskMultiplier    = [math]::Max( (Get-ExcelRound -Value ($concurrentSubTasks / $NodeCount)), 2 )
$fileRestoreMax       = $concurrentSubTasks
$fileRestoreMultiplier = $subTaskMultiplier

$grpcDefaultCq = [math]::Max( (Get-ExcelRound -Value ($CpuCores / 4)), 1 )

$memSizeMb = if ($isTenGig) { 2048 } else { 4096 }

$recommendations = New-Object System.Collections.Generic.List[PSCustomObject]

function Add-Recommendation {
    param($FlagType, $ServiceName, $FlagName, $Value, $DefaultValue, $Notes, $Command)
    $recommendations.Add([PSCustomObject]@{
        FlagType     = $FlagType
        ServiceName  = $ServiceName
        FlagName     = $FlagName
        Value        = $Value
        DefaultValue = $DefaultValue
        Notes        = $Notes
        Command      = $Command
    })
}

$clusterCmd = {
    param($Service, $Flag, $Value)
    "iris_cli cluster update-gflag service-name=$Service gflag-name=$Flag gflag-value=$Value reason=`"Increasing Parallelism for EPIC Backup`" effective-now=true"
}
$agentCmd = {
    param($Flag, $Value)
    "./magneto_agent_debug_tool update-gflag-settings --agent_gflag_settings=$($Flag):$Value --agent_endpoints=$AgentEndpoint --agent_gflag_settings_effective_now=true"
}

# --- Cluster gflags (magneto) ---
Add-Recommendation -FlagType "Cluster" -ServiceName "magneto" -FlagName $gatekeeperFlagName `
    -Value $gatekeeperValue -DefaultValue 4 `
    -Notes "If host/NIC is >10GbE use 16, else use 12" `
    -Command (& $clusterCmd "magneto" $gatekeeperFlagName $gatekeeperValue)

Add-Recommendation -FlagType "Cluster" -ServiceName "magneto" -FlagName "magneto_slave_nas_max_concurrent_sub_tasks" `
    -Value $concurrentSubTasks -DefaultValue 12 `
    -Notes "2x the gatekeeper value" `
    -Command (& $clusterCmd "magneto" "magneto_slave_nas_max_concurrent_sub_tasks" $concurrentSubTasks)

Add-Recommendation -FlagType "Cluster" -ServiceName "magneto" -FlagName "magneto_slave_nas_concurrent_sub_tasks_multiplier" `
    -Value $subTaskMultiplier -DefaultValue 2 `
    -Notes "Max of (concurrent sub tasks / node count), 2" `
    -Command (& $clusterCmd "magneto" "magneto_slave_nas_concurrent_sub_tasks_multiplier" $subTaskMultiplier)

Add-Recommendation -FlagType "Cluster" -ServiceName "magneto" -FlagName "magneto_slave_file_restore_max_concurrent_sub_tasks" `
    -Value $fileRestoreMax -DefaultValue 12 `
    -Notes "Same as concurrent sub tasks" `
    -Command (& $clusterCmd "magneto" "magneto_slave_file_restore_max_concurrent_sub_tasks" $fileRestoreMax)

Add-Recommendation -FlagType "Cluster" -ServiceName "magneto" -FlagName "magneto_slave_file_restore_concurrent_sub_tasks_multiplier" `
    -Value $fileRestoreMultiplier -DefaultValue 2 `
    -Notes "Same as sub tasks multiplier" `
    -Command (& $clusterCmd "magneto" "magneto_slave_file_restore_concurrent_sub_tasks_multiplier" $fileRestoreMultiplier)

if ($HostOS -eq "AIX") {
    Add-Recommendation -FlagType "Cluster" -ServiceName "magneto" -FlagName "magneto_java_agent_send_terminate_rpc" `
        -Value "true" -DefaultValue "false" `
        -Notes "Overcomes a memory leak that slows down ingest over time on AIX" `
        -Command (& $clusterCmd "magneto" "magneto_java_agent_send_terminate_rpc" "true")
}

Add-Recommendation -FlagType "Cluster" -ServiceName "bridge_proxy" -FlagName "bridge_magneto_skip_local_ip_get" `
    -Value "true" -DefaultValue "false" `
    -Notes "Skips a local IP lookup that can slow ingest on some network setups" `
    -Command (& $clusterCmd "bridge_proxy" "bridge_magneto_skip_local_ip_get" "true")

# --- Agent gflags: Linux ---
if ($HostOS -eq "LINUX") {
    Add-Recommendation -FlagType "Agent" -ServiceName "/etc/cohesity-agent/agent.cfg" -FlagName "max_rpc_context_count" `
        -Value 32 -DefaultValue 16 `
        -Notes "Static starting recommendation; helps primarily restores" `
        -Command (& $agentCmd "max_rpc_context_count" 32)

    Add-Recommendation -FlagType "Agent" -ServiceName "/etc/cohesity-agent/agent.cfg" -FlagName "grpc_server_cq_control_threads" `
        -Value 2 -DefaultValue 1 `
        -Notes "6.8.1_u2 and later only" `
        -Command (& $agentCmd "grpc_server_cq_control_threads" 2)

    Add-Recommendation -FlagType "Agent" -ServiceName "/etc/cohesity-agent/agent.cfg" -FlagName "grpc_server_cq_data_threads" `
        -Value 2 -DefaultValue 1 `
        -Notes "6.8.1_u2 and later only" `
        -Command (& $agentCmd "grpc_server_cq_data_threads" 2)

    Add-Recommendation -FlagType "Agent" -ServiceName "/etc/cohesity-agent/agent.cfg" -FlagName "grpc_number_of_default_cq" `
        -Value $grpcDefaultCq -DefaultValue 1 `
        -Notes "CPU cores / 4 (min 1); 6.8.1_u2 and later only" `
        -Command (& $agentCmd "grpc_number_of_default_cq" $grpcDefaultCq)
}

# --- Agent gflags: AIX ---
if ($HostOS -eq "AIX") {
    Add-Recommendation -FlagType "Agent" -ServiceName "/etc/aix_agent_config.cfg" -FlagName "JavaAgentTerminateForcefully" `
        -Value "true" -DefaultValue "false" `
        -Notes "Overcomes a memory leak that slows down ingest over time on AIX" `
        -Command (& $agentCmd "JavaAgentTerminateForcefully" "true")

    Add-Recommendation -FlagType "Agent" -ServiceName "/etc/aix_agent_config.cfg" -FlagName "StorageProxyMaxBrickReadSize" `
        -Value 2097152 -DefaultValue "Unknown" `
        -Notes "Static recommendation for AIX EPIC backup tuning" `
        -Command (& $agentCmd "StorageProxyMaxBrickReadSize" 2097152)

    Add-Recommendation -FlagType "Agent" -ServiceName "/etc/aix_agent_config.cfg" -FlagName "JavaAgentGrpcThreadpoolSize" `
        -Value 128 -DefaultValue 32 `
        -Notes "Static starting recommendation; 6.8.1_u2 and later only. Revisit if AIX host CPU/load is unusually high or low" `
        -Command (& $agentCmd "JavaAgentGrpcThreadpoolSize" 128)

    # --- env.sh settings (AIX only, hand-edited - no CLI command) ---
    $xmxLine = 'COHESITY_AGENT_XMX="${COHESITY_AGENT_XMX:--Xmx' + $memSizeMb + 'm}"'
    Add-Recommendation -FlagType "env.sh" -ServiceName "/usr/local/cohesity/set_env.sh" -FlagName "COHESITY_AGENT_XMX" `
        -Value "${memSizeMb}m" -DefaultValue "1024m" `
        -Notes "Can be tweaked higher depending on available server memory" `
        -Command "Edit /usr/local/cohesity/set_env.sh and set: $xmxLine"

    $maxDirectLine = 'COHESITY_AGENT_MAX_DIRECT_MEMORY_SIZE="${COHESITY_AGENT_MAX_DIRECT_MEMORY_SIZE:--XX:MaxDirectMemorySize=' + $memSizeMb + 'm}"'
    Add-Recommendation -FlagType "env.sh" -ServiceName "/usr/local/cohesity/set_env.sh" -FlagName "COHESITY_AGENT_MAX_DIRECT_MEMORY_SIZE" `
        -Value "${memSizeMb}m" -DefaultValue "1024m" `
        -Notes "Can be tweaked higher depending on available server memory" `
        -Command "Edit /usr/local/cohesity/set_env.sh and set: $maxDirectLine"

    $envShLines = @($xmxLine, $maxDirectLine)
}

# ------------------------------------------------------------------------
# Agent config file stanza (/etc/aix_agent_config.cfg on AIX, or
# /etc/cohesity-agent/agent.cfg on Linux) - built from the agent
# recommendations above, in the user_settings/gflag_setting_vec format the
# file expects. This is an alternative to magneto_agent_debug_tool.
# ------------------------------------------------------------------------
$agentFlagsForStanza = $recommendations | Where-Object { $_.FlagType -eq "Agent" }

$stanza = New-Object System.Collections.Generic.List[string]
$stanza.Add("user_settings {")
foreach ($flag in $agentFlagsForStanza) {
    $stanza.Add("  gflag_setting_vec {")
    $stanza.Add("    name: `"$($flag.FlagName)`"")
    $stanza.Add("    value: `"$($flag.Value)`"")
    $stanza.Add("  }")
}
$stanza.Add("}")
$agentConfigStanza = $stanza

# ------------------------------------------------------------------------
# Agent restart commands - needed after editing the agent config file
# directly or (on AIX) after editing set_env.sh.
# ------------------------------------------------------------------------
$agentRestartCommands = if ($HostOS -eq "AIX") {
    @(
        "/usr/local/cohesity/agent/aix_agent.sh stop",
        "/usr/local/cohesity/agent/aix_agent.sh start",
        "/usr/local/cohesity/agent/aix_agent.sh status"
    )
} else {
    @(
        "sudo systemctl restart cohesity-agent",
        "sudo systemctl status cohesity-agent"
    )
}

# ------------------------------------------------------------------------
# Screen output
# ------------------------------------------------------------------------
Write-Host ""
Write-Host "=== EPIC Cache/IRIS gflag Recommendations ===" -ForegroundColor Cyan
Write-Host "Nodes: $NodeCount | Host OS: $HostOS | NIC Speed: $NicSpeed | CPU Cores: $CpuCores"
Write-Host ""

$recommendations | Format-Table -Property FlagType, ServiceName, FlagName, Value, DefaultValue -AutoSize -Wrap

Write-Host "--- Commands to apply (copy/paste) ---" -ForegroundColor Cyan
foreach ($rec in $recommendations) {
    Write-Host ""
    Write-Host "# $($rec.FlagName) -> $($rec.Value)  ($($rec.Notes))" -ForegroundColor Yellow
    Write-Host $rec.Command
}
Write-Host ""

Write-Host "--- Alternative: $agentConfigFilePath stanza (append if new, merge if user_settings already exists) ---" -ForegroundColor Cyan
foreach ($stanzaLine in $agentConfigStanza) {
    Write-Host $stanzaLine
}
Write-Host ""

# ------------------------------------------------------------------------
# File output - full recommendations + instructions
# ------------------------------------------------------------------------
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("EPIC Cache/IRIS gflag Recommendations for Linux/AIX Physical Mount Hosts")
$lines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add("")
$lines.Add("Inputs")
$lines.Add("------")
$lines.Add("Number of nodes in Cohesity cluster : $NodeCount")
$lines.Add("Mount host operating system         : $HostOS")
$lines.Add("Mount host NIC speed range           : $NicSpeed")
$lines.Add("Mount host CPU cores                : $CpuCores")
$lines.Add("")
$lines.Add("How to apply these settings")
$lines.Add("----------------------------")
$lines.Add("1. Cluster gflags: run the iris_cli commands below from any CVM (or via SSH to the cluster VIP).")
$lines.Add("   A paste-ready version of these commands, with the leading 'iris_cli' stripped off so they can")
$lines.Add("   be pasted directly into an already-open iris_cli session, is included below.")
$lines.Add("2. Agent gflags: run the magneto_agent_debug_tool commands below from an SSH session on the Cohesity")
$lines.Add("   cluster - replace the placeholder with the actual mount host hostname/IP if you did not pass")
$lines.Add("   -AgentEndpoint.")
$lines.Add("2a. Agent gflags - alternative to magneto_agent_debug_tool: edit $agentConfigFilePath on the mount")
$lines.Add("    host directly and add the stanza shown below.")
$lines.Add("    - If the file does NOT already contain a user_settings stanza, append the whole block to the")
$lines.Add("      end of the file.")
$lines.Add("    - If a user_settings stanza already exists, merge each gflag_setting_vec entry into the")
$lines.Add("      existing stanza instead of adding a second one - the agent only reads the first")
$lines.Add("      user_settings block. Update the value if an entry with the same name is already present,")
$lines.Add("      otherwise add a new gflag_setting_vec entry for it.")
$lines.Add("    - Restart the Cohesity agent after editing (see 'Restarting the Cohesity Agent' below).")
$lines.Add("3. env.sh settings (AIX only): manually edit /usr/local/cohesity/set_env.sh on the mount host and")
$lines.Add("   update the two existing settings shown below, then restart the Cohesity agent (see")
$lines.Add("   'Restarting the Cohesity Agent' below).")
$lines.Add("4. After applying, kick off a test backup and monitor throughput before rolling out further.")
$lines.Add("")
$lines.Add("Recommended Settings")
$lines.Add("---------------------")

foreach ($rec in $recommendations) {
    $lines.Add("")
    $lines.Add("[$($rec.FlagType)] $($rec.ServiceName) -> $($rec.FlagName)")
    $lines.Add("  Recommended value : $($rec.Value)")
    $lines.Add("  Default value     : $($rec.DefaultValue)")
    $lines.Add("  Notes             : $($rec.Notes)")
    $lines.Add("  Command           : $($rec.Command)")
}

$lines.Add("")
$lines.Add("Cluster iris_cli Commands (paste-ready)")
$lines.Add("----------------------------------------")
$lines.Add("Leading 'iris_cli' stripped off so these can be pasted directly into an already-open iris_cli")
$lines.Add("session, one line at a time.")
$lines.Add("")
$irisCliLines = $recommendations |
    Where-Object { $_.FlagType -eq "Cluster" } |
    ForEach-Object { $_.Command -replace '^iris_cli\s+', '' }
foreach ($irisCliLine in $irisCliLines) {
    $lines.Add($irisCliLine)
}

$lines.Add("")
$lines.Add("Agent magneto_agent_debug_tool Commands (paste-ready)")
$lines.Add("-------------------------------------------------------")
$lines.Add("Run from an SSH session on the Cohesity cluster. Replace the placeholder with the actual mount")
$lines.Add("host hostname/IP if you did not pass -AgentEndpoint.")
$lines.Add("")
$agentCliLines = $recommendations |
    Where-Object { $_.FlagType -eq "Agent" } |
    ForEach-Object { $_.Command }
foreach ($agentCliLine in $agentCliLines) {
    $lines.Add($agentCliLine)
}

$lines.Add("")
$lines.Add("Agent Config File Stanza ($agentConfigFilePath)")
$lines.Add("---------------------------------------------------")
$lines.Add("Alternative to magneto_agent_debug_tool for the agent gflags above. Append this block if")
$lines.Add("$agentConfigFilePath has no user_settings stanza yet, or merge the gflag_setting_vec")
$lines.Add("entries into the existing stanza if one is already present (do not create a second one).")
$lines.Add("")
foreach ($stanzaLine in $agentConfigStanza) {
    $lines.Add($stanzaLine)
}

if ($HostOS -eq "AIX") {
    $lines.Add("")
    $lines.Add("env.sh Settings (/usr/local/cohesity/set_env.sh)")
    $lines.Add("---------------------------------------------------")
    $lines.Add("AIX only. These settings already exist in /usr/local/cohesity/set_env.sh on the mount host -")
    $lines.Add("edit the file and update the existing values for the two lines below. Restart the Cohesity")
    $lines.Add("agent after editing (see 'Restarting the Cohesity Agent' below).")
    $lines.Add("")
    foreach ($envLine in $envShLines) {
        $lines.Add($envLine)
    }
}

$lines.Add("")
$lines.Add("Restarting the Cohesity Agent")
$lines.Add("------------------------------")
$lines.Add("Run on the mount host after editing $agentConfigFilePath or set_env.sh:")
$lines.Add("")
foreach ($restartCmd in $agentRestartCommands) {
    $lines.Add($restartCmd)
}

$lines.Add("")
$lines.Add("Questions or suggestions: contact Brian Seltzer or Adaikkappan Arumugam.")

$lines | Out-File -FilePath $OutputFile -Encoding utf8

Write-Host "Recommendations written to: $OutputFile" -ForegroundColor Green
