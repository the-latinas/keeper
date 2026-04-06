#requires -Version 5.1
<#
  Loads lighthouse_csv_v7/process_recordings.csv into dbo.process_recordings.
  Plain bcp cannot handle quoted commas in interventions_applied (see process_recordings_bcp_errors.txt).

  Usage:
    cd ...\keeper\scripts
    . .\Load-KeeperEnv.ps1
    .\Import-ProcessRecordings.ps1
#>
param(
    [string] $Server = $env:AZURE_SQL_SERVER,
    [string] $Database = $env:AZURE_SQL_DATABASE,
    [string] $User = $env:AZURE_SQL_USER,
    [string] $PlainPassword,
    [string] $CsvPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Server)) { throw "Set AZURE_SQL_SERVER or pass -Server." }
if ([string]::IsNullOrWhiteSpace($Database)) { throw "Set AZURE_SQL_DATABASE or pass -Database." }
if ([string]::IsNullOrWhiteSpace($User)) { throw "Set AZURE_SQL_USER or pass -User." }

if (-not $CsvPath) {
    $CsvPath = Join-Path (Split-Path $PSScriptRoot -Parent) "lighthouse_csv_v7\process_recordings.csv"
}
if (-not (Test-Path -LiteralPath $CsvPath)) { throw "CSV not found: $CsvPath" }

$pwdPlain = $PlainPassword
if (-not $pwdPlain) { $pwdPlain = $env:AZURE_SQL_PASSWORD }
if (-not $pwdPlain) {
    $sec = Read-Host -AsSecureString "SQL password"
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $pwdPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$cs = "Server=tcp:$Server,1433;Database=$Database;User ID=$User;Password=$pwdPlain;Encrypt=True;TrustServerCertificate=False;Connection Timeout=120;"

function Get-NullStr([string] $s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    return $s
}
function Get-NullInt([string] $s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    $n = 0
    if ([int]::TryParse($s.Trim(), [ref]$n)) { return $n }
    return [DBNull]::Value
}
function Get-ReqBool([string] $s) {
    $t = $s.Trim()
    if ($t -in @("True", "true", "1")) { return $true }
    return $false
}

Add-Type -AssemblyName System.Data

$dt = New-Object System.Data.DataTable
[void]$dt.Columns.Add("recording_id", [int])
[void]$dt.Columns.Add("resident_id", [int])
[void]$dt.Columns.Add("session_date", [datetime])
[void]$dt.Columns.Add("social_worker", [string])
[void]$dt.Columns.Add("session_type", [string])
[void]$dt.Columns.Add("session_duration_minutes", [int])
[void]$dt.Columns.Add("emotional_state_observed", [string])
[void]$dt.Columns.Add("emotional_state_end", [string])
[void]$dt.Columns.Add("session_narrative", [string])
[void]$dt.Columns.Add("interventions_applied", [string])
[void]$dt.Columns.Add("follow_up_actions", [string])
[void]$dt.Columns.Add("progress_noted", [bool])
[void]$dt.Columns.Add("concerns_flagged", [bool])
[void]$dt.Columns.Add("referral_made", [bool])
[void]$dt.Columns.Add("notes_restricted", [string])

foreach ($c in $dt.Columns) { $c.AllowDBNull = $true }
$dt.Columns["recording_id"].AllowDBNull = $false
$dt.Columns["resident_id"].AllowDBNull = $false
$dt.Columns["session_date"].AllowDBNull = $false
$dt.Columns["progress_noted"].AllowDBNull = $false
$dt.Columns["concerns_flagged"].AllowDBNull = $false
$dt.Columns["referral_made"].AllowDBNull = $false

$rows = Import-Csv -LiteralPath $CsvPath
foreach ($r in $rows) {
    $dr = $dt.NewRow()
    $dr["recording_id"] = [int]$r.recording_id
    $dr["resident_id"] = [int]$r.resident_id
    $dr["session_date"] = [DateTime]::Parse($r.session_date.Trim(), [System.Globalization.CultureInfo]::InvariantCulture)
    $dr["social_worker"] = Get-NullStr $r.social_worker
    $dr["session_type"] = Get-NullStr $r.session_type
    $vd = Get-NullInt $r.session_duration_minutes
    if ($vd -is [int]) { $dr["session_duration_minutes"] = $vd } else { $dr["session_duration_minutes"] = [DBNull]::Value }
    $dr["emotional_state_observed"] = Get-NullStr $r.emotional_state_observed
    $dr["emotional_state_end"] = Get-NullStr $r.emotional_state_end
    $dr["session_narrative"] = Get-NullStr $r.session_narrative
    $dr["interventions_applied"] = Get-NullStr $r.interventions_applied
    $dr["follow_up_actions"] = Get-NullStr $r.follow_up_actions
    $dr["progress_noted"] = Get-ReqBool $r.progress_noted
    $dr["concerns_flagged"] = Get-ReqBool $r.concerns_flagged
    $dr["referral_made"] = Get-ReqBool $r.referral_made
    $dr["notes_restricted"] = Get-NullStr $r.notes_restricted
    $dt.Rows.Add($dr)
}

$conn = New-Object System.Data.SqlClient.SqlConnection $cs
$conn.Open()
try {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "DELETE FROM dbo.process_recordings;"
    $deleted = $cmd.ExecuteNonQuery()
    Write-Host "Cleared dbo.process_recordings (rows deleted: $deleted)"

    $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($conn)
    $bulk.DestinationTableName = "dbo.process_recordings"
    $bulk.BatchSize = 500
    $bulk.BulkCopyTimeout = 600
    foreach ($c in $dt.Columns) {
        [void]$bulk.ColumnMappings.Add($c.ColumnName, $c.ColumnName)
    }
    $bulk.WriteToServer($dt)
    Write-Host "Loaded $($dt.Rows.Count) rows into dbo.process_recordings."
}
finally {
    $conn.Close()
}

Write-Host 'Done. VERIFY: SELECT COUNT(*) FROM dbo.process_recordings; expect 2819 rows.'
