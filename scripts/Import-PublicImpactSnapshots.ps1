#requires -Version 5.1
<#
  Loads lighthouse_csv_v7/public_impact_snapshots.csv into dbo.public_impact_snapshots.
  Plain bcp cannot handle quoted commas in summary_text / metric_payload_json (see public_impact_snapshots_bcp_errors.txt).

  Usage:
    cd ...\keeper\scripts
    . .\Load-KeeperEnv.ps1
    .\Import-PublicImpactSnapshots.ps1
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
    $CsvPath = Join-Path (Split-Path $PSScriptRoot -Parent) "lighthouse_csv_v7\public_impact_snapshots.csv"
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
function Get-ReqBool([string] $s) {
    $t = $s.Trim()
    if ($t -in @("True", "true", "1")) { return $true }
    return $false
}
function Get-NullDateTime([string] $s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    try {
        return [DateTime]::Parse($s.Trim(), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces)
    } catch {
        return [DBNull]::Value
    }
}

Add-Type -AssemblyName System.Data

$dt = New-Object System.Data.DataTable
[void]$dt.Columns.Add("snapshot_id", [int])
[void]$dt.Columns.Add("snapshot_date", [datetime])
[void]$dt.Columns.Add("headline", [string])
[void]$dt.Columns.Add("summary_text", [string])
[void]$dt.Columns.Add("metric_payload_json", [string])
[void]$dt.Columns.Add("is_published", [bool])
[void]$dt.Columns.Add("published_at", [datetime])

foreach ($c in $dt.Columns) { $c.AllowDBNull = $true }
$dt.Columns["snapshot_id"].AllowDBNull = $false
$dt.Columns["snapshot_date"].AllowDBNull = $false
$dt.Columns["is_published"].AllowDBNull = $false

$rows = Import-Csv -LiteralPath $CsvPath
foreach ($r in $rows) {
    $dr = $dt.NewRow()
    $dr["snapshot_id"] = [int]$r.snapshot_id
    $dr["snapshot_date"] = [DateTime]::Parse($r.snapshot_date.Trim(), [System.Globalization.CultureInfo]::InvariantCulture)
    $dr["headline"] = Get-NullStr $r.headline
    $dr["summary_text"] = Get-NullStr $r.summary_text
    $dr["metric_payload_json"] = Get-NullStr $r.metric_payload_json
    $dr["is_published"] = Get-ReqBool $r.is_published
    $pub = Get-NullDateTime $r.published_at
    if ($pub -is [DateTime]) { $dr["published_at"] = $pub } else { $dr["published_at"] = [DBNull]::Value }
    $dt.Rows.Add($dr)
}

$conn = New-Object System.Data.SqlClient.SqlConnection $cs
$conn.Open()
try {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "DELETE FROM dbo.public_impact_snapshots;"
    $deleted = $cmd.ExecuteNonQuery()
    Write-Host "Cleared dbo.public_impact_snapshots (rows deleted: $deleted)"

    $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($conn)
    $bulk.DestinationTableName = "dbo.public_impact_snapshots"
    $bulk.BatchSize = 100
    $bulk.BulkCopyTimeout = 120
    foreach ($c in $dt.Columns) {
        [void]$bulk.ColumnMappings.Add($c.ColumnName, $c.ColumnName)
    }
    $bulk.WriteToServer($dt)
    Write-Host "Loaded $($dt.Rows.Count) rows into dbo.public_impact_snapshots."
}
finally {
    $conn.Close()
}

Write-Host 'Done. VERIFY: SELECT COUNT(*) FROM dbo.public_impact_snapshots; expect 50 rows.'
