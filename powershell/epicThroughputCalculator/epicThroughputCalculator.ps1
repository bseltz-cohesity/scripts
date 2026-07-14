<#
.SYNOPSIS
    Epic Iris Backup & Restore Throughput Calculator.

.DESCRIPTION
    PowerShell replacement for the "Epic Throughput Calculator.xlsx" spreadsheet
    (Iris Backup & Restore Sizer tab). Given the Iris database size and the
    connectivity/cluster characteristics of the environment, estimates Full,
    Incremental, and Pure Incremental backup durations (and the resulting
    restore duration), and identifies the throughput bottleneck for each.

    The three theoretical throughput paths modeled are the same as in the
    spreadsheet:
      - Lun Read      : Iris mount host -> storage array (FC) bandwidth
      - Transfer      : Iris mount host -> Cohesity cluster (NIC) bandwidth
      - Cluster Ingest: Cohesity cluster node ingest throughput

    For each backup type, the duration is the MAX of the three path durations
    (i.e. the slowest path is the bottleneck), exactly as computed in the
    spreadsheet's hidden "DON'T CHANGE THIS AREA" calculation block.

    NOTE ON BOTTLENECKS: the NIC transfer path is derated per backup type
    (Full x0.75, Incremental x0.75x0.4, Pure Incremental x0.75x0.6) while the
    cluster ingest path is not derated at all - this matches the source
    spreadsheet's own formulas. Because of this, the NIC can carry a higher
    raw Gb rating than the cluster and still end up the bottleneck for
    Incremental/Pure Incremental backups, since its effective throughput for
    those backup types falls further below its own rating than the cluster's
    does. The Inputs section below reports the FC/NIC figures at their
    effective (derated) throughput rather than raw theoretical max, so this
    is easier to reason about at a glance.

.PARAMETER ODBSizeTB
    Iris database size, in TB, that will be backed up / restored.

.PARAMETER FcSpeedGb
    Iris Lun Read Speed (FC Speed): the Iris mount host's connectivity
    bandwidth to the storage array, in Gigabits (not GigaBytes).

.PARAMETER NicSpeedGb
    Transfer Speed (NIC Speed): the Iris mount host's network bandwidth to
    the Cohesity cluster, in Gigabits (not GigaBytes).

.PARAMETER ClusterNodes
    Number of nodes in the Cohesity cluster.

.PARAMETER NodeSpeedMBps
    Per-node ingest throughput of the Cohesity cluster, in MBps (write
    bandwidth).

.PARAMETER NodeClass
    HYBRID or FLASH. If set to FLASH and NodeSpeedMBps is less than 400, then it will raise it to 400

.EXAMPLE
    .\epicThroughputCalculator.ps1 -ODBSizeTB 70 -FcSpeedGb 32 -NicSpeedGb 25 -ClusterNodes 8 -NodeSpeedMBps 150

.NOTES
    Author: Generated to replace Epic Throughput Calculator.xlsx
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "ODB size in TB")]
    [ValidateRange(0.01, [double]::MaxValue)]
    [double]$ODBSizeTB,

    [Parameter(Mandatory = $false, HelpMessage = "Iris Lun Read Speed / FC Speed, in Gigabits")]
    [ValidateRange(0.01, [double]::MaxValue)]
    [double]$FcSpeedGb = 32,

    [Parameter(Mandatory = $false, HelpMessage = "Transfer Speed / NIC Speed, in Gigabits")]
    [ValidateRange(0.01, [double]::MaxValue)]
    [double]$NicSpeedGb = 10,

    [Parameter(Mandatory = $true, HelpMessage = "Number of Nodes in the Cohesity Cluster")]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$ClusterNodes,

    [Parameter(Mandatory = $false, HelpMessage = "Per-Node Ingest Throughput (Write Bandwidth) in MBps")]
    [ValidateRange(0.01, [double]::MaxValue)]
    [double]$NodeSpeedMBps = 150,

    [Parameter(Mandatory = $false, HelpMessage = "Node Class (HYBRID or FLASH)")]
    [ValidateSet("HYBRID", "FLASH")]
    [string]$NodeClass = "HYBRID"
)

# NodeClass is a helper to set the NodeSpeedMBps
if($NodeClass -eq 'FLASH' -and $NodeSpeedMBps -lt 400){
    $NodeSpeedMBps = 400
}

# ---------------------------------------------------------------------------
# Internal calculation constants ("DON'T CHANGE THIS AREA" in the spreadsheet)
# ---------------------------------------------------------------------------
$FullChangeRatePct       = 100   # Full backup always moves 100% of the data set
$IncrementalChangeRatePct = 33   # Incremental data change rate assumption
$PureIncChangeRatePct     = 15   # Pure Incremental data change rate assumption

$LunReadEfficiency        = 0.75 # Real-world derate of theoretical FC read speed
$TransferEfficiency       = 0.75 # Real-world derate of theoretical NIC speed
$IncrementalTransferFactor = 0.4 # Incremental transfer efficiency vs. Full
$PureIncTransferFactor     = 0.6 # Pure Incremental transfer efficiency vs. Full

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

function ConvertTo-HourMinuteString {
    # Mirrors Excel's TEXT(value/24,"[h]:mm") behavior, which TRUNCATES
    # (floors) to the nearest whole minute rather than rounding.
    param([double]$Hours)
    $totalSeconds = $Hours * 3600
    $ts = [TimeSpan]::FromSeconds($totalSeconds)
    $wholeHours = [Math]::Floor($ts.TotalHours)
    return '{0}:{1:00}' -f [int]$wholeHours, $ts.Minutes
}

function Get-Bottleneck {
    param(
        [double]$LunReadHours,
        [double]$TransferHours,
        [double]$IngestHours,
        [double]$DurationHours
    )

    if ($DurationHours -eq $IngestHours) {
        return "Cluster - Increase the Number of Nodes"
    }
    elseif ($DurationHours -eq $TransferHours) {
        return "Network - Increase the NIC Bandwidth"
    }
    else {
        return "Backend Storage - Increase the FC Connectivity"
    }
}

# ---------------------------------------------------------------------------
# Core throughput math (mirrors the spreadsheet's F:I calculation columns)
# ---------------------------------------------------------------------------

# Data Set Size (same for Full / Incremental / Pure Incremental)
$DataSetSizeGB = $ODBSizeTB * 1024

# Data actually moved for each backup type
$FullChangeGB       = $DataSetSizeGB * ($FullChangeRatePct / 100)
$IncrementalChangeGB = $DataSetSizeGB * ($IncrementalChangeRatePct / 100)
$PureIncChangeGB     = $DataSetSizeGB * ($PureIncChangeRatePct / 100)

# Cluster ingest rate (GB/hour) - not derated
$ClusterIngestRateGBph = ($ClusterNodes * $NodeSpeedMBps / 1024) * 3600

# Lun read speed (GB/hour) - theoretical and @75% effective
$LunReadSpeedTheoreticalGBph = ($FcSpeedGb / 8) * 3600
$LunReadSpeedEffectiveGBph   = $LunReadSpeedTheoreticalGBph * $LunReadEfficiency

# Transfer speed (GB/hour) - theoretical, then @75% effective per backup type
$TransferSpeedTheoreticalGBph = ($NicSpeedGb / 8) * 3600
$TransferSpeedFullGBph        = $TransferSpeedTheoreticalGBph * $TransferEfficiency
$TransferSpeedIncrementalGBph = $TransferSpeedFullGBph * $IncrementalTransferFactor
$TransferSpeedPureIncGBph     = $TransferSpeedFullGBph * $PureIncTransferFactor

# Effective (fully derated) throughput figures shown in the Inputs section
# below. Lun Read gets the base 0.75 efficiency derate (same for every backup
# type). Transfer/NIC is shown per backup type since Incremental and Pure
# Incremental apply an additional derate on top of the base 0.75 (x0.4 and
# x0.6 respectively) - these are the actual final numbers that drive each
# backup type's bottleneck decision. Cluster ingest has no derate in this
# model, so its "effective" figure equals its raw rating.
$LunReadEffectiveMaxGBps           = [math]::Round(($FcSpeedGb / 8) * $LunReadEfficiency, 2)
$TransferFullEffectiveGBps         = [math]::Round($TransferSpeedFullGBph / 3600, 2)
$TransferIncrementalEffectiveGBps  = [math]::Round($TransferSpeedIncrementalGBph / 3600, 2)
$TransferPureIncEffectiveGBps      = [math]::Round($TransferSpeedPureIncGBph / 3600, 2)
$ClusterIngestEffectiveMaxGBps     = [math]::Round(($ClusterNodes * $NodeSpeedMBps) / 1024, 2)

function Get-BackupProfile {
    param(
        [double]$ChangeGB,
        [double]$NicSpeedGbph
    )

    $lunReadHours  = $DataSetSizeGB / $LunReadSpeedEffectiveGBph
    $transferHours = $ChangeGB / $NicSpeedGbph
    $ingestHours   = $ChangeGB / $ClusterIngestRateGBph

    $durationHours = [math]::Max([math]::Max($lunReadHours, $transferHours), $ingestHours)
    $bottleneck = Get-Bottleneck -LunReadHours $lunReadHours -TransferHours $transferHours -IngestHours $ingestHours -DurationHours $durationHours

    [pscustomobject]@{
        LunReadHours   = $lunReadHours
        TransferHours  = $transferHours
        IngestHours    = $ingestHours
        DurationHours  = $durationHours
        DurationString = ConvertTo-HourMinuteString -Hours $durationHours
        Bottleneck     = $bottleneck
    }
}

$Full            = Get-BackupProfile -ChangeGB $FullChangeGB -NicSpeedGbph $TransferSpeedFullGBph
$Incremental     = Get-BackupProfile -ChangeGB $IncrementalChangeGB -NicSpeedGbph $TransferSpeedIncrementalGBph
$PureIncremental = Get-BackupProfile -ChangeGB $PureIncChangeGB -NicSpeedGbph $TransferSpeedPureIncGBph

# Restore uses the same throughput profile as a Full backup
$Restore = $Full

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

Write-Host "`n=== Epic Iris Backup & Restore Throughput Calculator ===`n" -ForegroundColor Cyan
Write-Host "Inputs`n" -ForegroundColor Yellow
Write-Host ("  ODB Size                : {0} TB" -f $ODBSizeTB)
Write-Host ("  FC Speed                : {0} Gb  ({1} GBps effective)" -f $FcSpeedGb, $LunReadEffectiveMaxGBps)
Write-Host ("  NIC Speed               : {0} Gb  ({1} GBps effective)" -f $NicSpeedGb, $TransferFullEffectiveGBps)
Write-Host ("  Number of Cluster Nodes : {0}" -f $ClusterNodes)
Write-Host ("  Node Ingest Speed       : {0} MBps  ({1} GBps cluster effective)`n" -f $NodeSpeedMBps, $ClusterIngestEffectiveMaxGBps)
Write-Host "Results`n" -ForegroundColor Yellow
Write-Host "Mount Host Method:`n"
Write-Host ("  Full Backup Duration/Bottleneck        : {0} ({1})" -f $Full.DurationString, $Full.Bottleneck)
Write-Host ("  Incremental Backup Duration/Bottleneck : {0} ({1})" -f $Incremental.DurationString, $Incremental.Bottleneck)
Write-Host ("  Restore Duration/Bottleneck            : {0} ({1})" -f $Restore.DurationString, $Restore.Bottleneck)
Write-Host "`nPure Method:`n"
Write-Host ("  Pure Incremental Duration/Bottleneck   : {0} ({1})`n" -f $PureIncremental.DurationString, $PureIncremental.Bottleneck)
