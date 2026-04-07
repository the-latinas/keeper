#requires -Version 5.1
<#
  Loads lighthouse_csv_v7/residents.csv into dbo.residents via Import-Csv + SqlBulkCopy.
  Fixes residents_bcp_errors.txt (header row truncation: e.g. sub_cat_physical_abuse > NVARCHAR(20) in naive staging).

  Clears dependent data first: incident_reports (Restrict FK), then residents (CASCADE removes education, health, intervention, process, home_visitations rows for those residents).

  Usage:
    cd ...\keeper\scripts
    . .\Load-KeeperEnv.ps1
    .\Import-Residents.ps1
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
    $CsvPath = Join-Path (Split-Path $PSScriptRoot -Parent) "lighthouse_csv_v7\residents.csv"
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
    if ($null -eq $s) { return [DBNull]::Value }
    if ([string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    return $s
}
function Get-ReqBool([string] $s) {
    $t = if ($null -eq $s) { "" } else { $s.Trim() }
    if ($t -in @("True", "true", "1")) { return $true }
    return $false
}
function Get-NullDate([string] $s) {
    if ($null -eq $s -or [string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    try {
        $d = [DateTime]::Parse($s.Trim(), [System.Globalization.CultureInfo]::InvariantCulture)
        return $d.Date
    } catch {
        return [DBNull]::Value
    }
}
function Get-NullDateTime([string] $s) {
    if ($null -eq $s -or [string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    try {
        return [DateTime]::Parse($s.Trim(), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces)
    } catch {
        return [DBNull]::Value
    }
}

Add-Type -AssemblyName System.Data

$dt = New-Object System.Data.DataTable
$colDefs = @(
    @{ n = "resident_id"; t = [int] }
    @{ n = "case_control_no"; t = [string] }
    @{ n = "internal_code"; t = [string] }
    @{ n = "safehouse_id"; t = [int] }
    @{ n = "case_status"; t = [string] }
    @{ n = "sex"; t = [string] }
    @{ n = "date_of_birth"; t = [datetime] }
    @{ n = "birth_status"; t = [string] }
    @{ n = "place_of_birth"; t = [string] }
    @{ n = "religion"; t = [string] }
    @{ n = "case_category"; t = [string] }
    @{ n = "sub_cat_orphaned"; t = [bool] }
    @{ n = "sub_cat_trafficked"; t = [bool] }
    @{ n = "sub_cat_child_labor"; t = [bool] }
    @{ n = "sub_cat_physical_abuse"; t = [bool] }
    @{ n = "sub_cat_sexual_abuse"; t = [bool] }
    @{ n = "sub_cat_osaec"; t = [bool] }
    @{ n = "sub_cat_cicl"; t = [bool] }
    @{ n = "sub_cat_at_risk"; t = [bool] }
    @{ n = "sub_cat_street_child"; t = [bool] }
    @{ n = "sub_cat_child_with_hiv"; t = [bool] }
    @{ n = "is_pwd"; t = [bool] }
    @{ n = "pwd_type"; t = [string] }
    @{ n = "has_special_needs"; t = [bool] }
    @{ n = "special_needs_diagnosis"; t = [string] }
    @{ n = "family_is_4ps"; t = [bool] }
    @{ n = "family_solo_parent"; t = [bool] }
    @{ n = "family_indigenous"; t = [bool] }
    @{ n = "family_parent_pwd"; t = [bool] }
    @{ n = "family_informal_settler"; t = [bool] }
    @{ n = "date_of_admission"; t = [datetime] }
    @{ n = "age_upon_admission"; t = [string] }
    @{ n = "present_age"; t = [string] }
    @{ n = "length_of_stay"; t = [string] }
    @{ n = "referral_source"; t = [string] }
    @{ n = "referring_agency_person"; t = [string] }
    @{ n = "date_colb_registered"; t = [datetime] }
    @{ n = "date_colb_obtained"; t = [datetime] }
    @{ n = "assigned_social_worker"; t = [string] }
    @{ n = "initial_case_assessment"; t = [string] }
    @{ n = "date_case_study_prepared"; t = [datetime] }
    @{ n = "reintegration_type"; t = [string] }
    @{ n = "reintegration_status"; t = [string] }
    @{ n = "initial_risk_level"; t = [string] }
    @{ n = "current_risk_level"; t = [string] }
    @{ n = "date_enrolled"; t = [datetime] }
    @{ n = "date_closed"; t = [datetime] }
    @{ n = "created_at"; t = [datetime] }
    @{ n = "notes_restricted"; t = [string] }
)
foreach ($c in $colDefs) {
    [void]$dt.Columns.Add($c.n, $c.t)
}
foreach ($col in $dt.Columns) {
    $col.AllowDBNull = $true
}
$dt.Columns["resident_id"].AllowDBNull = $false
$dt.Columns["safehouse_id"].AllowDBNull = $false
foreach ($bn in @(
    "sub_cat_orphaned","sub_cat_trafficked","sub_cat_child_labor","sub_cat_physical_abuse","sub_cat_sexual_abuse",
    "sub_cat_osaec","sub_cat_cicl","sub_cat_at_risk","sub_cat_street_child","sub_cat_child_with_hiv",
    "is_pwd","has_special_needs","family_is_4ps","family_solo_parent","family_indigenous","family_parent_pwd","family_informal_settler"
)) {
    $dt.Columns[$bn].AllowDBNull = $false
}

$rows = Import-Csv -LiteralPath $CsvPath
foreach ($r in $rows) {
    $dr = $dt.NewRow()
    $dr["resident_id"] = [int]$r.resident_id
    $dr["case_control_no"] = Get-NullStr $r.case_control_no
    $dr["internal_code"] = Get-NullStr $r.internal_code
    $dr["safehouse_id"] = [int]$r.safehouse_id
    $dr["case_status"] = Get-NullStr $r.case_status
    $dr["sex"] = Get-NullStr $r.sex
    $v = Get-NullDate $r.date_of_birth
    if ($v -is [DateTime]) { $dr["date_of_birth"] = $v } else { $dr["date_of_birth"] = [DBNull]::Value }
    $dr["birth_status"] = Get-NullStr $r.birth_status
    $dr["place_of_birth"] = Get-NullStr $r.place_of_birth
    $dr["religion"] = Get-NullStr $r.religion
    $dr["case_category"] = Get-NullStr $r.case_category
    $dr["sub_cat_orphaned"] = Get-ReqBool $r.sub_cat_orphaned
    $dr["sub_cat_trafficked"] = Get-ReqBool $r.sub_cat_trafficked
    $dr["sub_cat_child_labor"] = Get-ReqBool $r.sub_cat_child_labor
    $dr["sub_cat_physical_abuse"] = Get-ReqBool $r.sub_cat_physical_abuse
    $dr["sub_cat_sexual_abuse"] = Get-ReqBool $r.sub_cat_sexual_abuse
    $dr["sub_cat_osaec"] = Get-ReqBool $r.sub_cat_osaec
    $dr["sub_cat_cicl"] = Get-ReqBool $r.sub_cat_cicl
    $dr["sub_cat_at_risk"] = Get-ReqBool $r.sub_cat_at_risk
    $dr["sub_cat_street_child"] = Get-ReqBool $r.sub_cat_street_child
    $dr["sub_cat_child_with_hiv"] = Get-ReqBool $r.sub_cat_child_with_hiv
    $dr["is_pwd"] = Get-ReqBool $r.is_pwd
    $dr["pwd_type"] = Get-NullStr $r.pwd_type
    $dr["has_special_needs"] = Get-ReqBool $r.has_special_needs
    $dr["special_needs_diagnosis"] = Get-NullStr $r.special_needs_diagnosis
    $dr["family_is_4ps"] = Get-ReqBool $r.family_is_4ps
    $dr["family_solo_parent"] = Get-ReqBool $r.family_solo_parent
    $dr["family_indigenous"] = Get-ReqBool $r.family_indigenous
    $dr["family_parent_pwd"] = Get-ReqBool $r.family_parent_pwd
    $dr["family_informal_settler"] = Get-ReqBool $r.family_informal_settler
    $v = Get-NullDate $r.date_of_admission
    if ($v -is [DateTime]) { $dr["date_of_admission"] = $v } else { $dr["date_of_admission"] = [DBNull]::Value }
    $dr["age_upon_admission"] = Get-NullStr $r.age_upon_admission
    $dr["present_age"] = Get-NullStr $r.present_age
    $dr["length_of_stay"] = Get-NullStr $r.length_of_stay
    $dr["referral_source"] = Get-NullStr $r.referral_source
    $dr["referring_agency_person"] = Get-NullStr $r.referring_agency_person
    $v = Get-NullDate $r.date_colb_registered
    if ($v -is [DateTime]) { $dr["date_colb_registered"] = $v } else { $dr["date_colb_registered"] = [DBNull]::Value }
    $v = Get-NullDate $r.date_colb_obtained
    if ($v -is [DateTime]) { $dr["date_colb_obtained"] = $v } else { $dr["date_colb_obtained"] = [DBNull]::Value }
    $dr["assigned_social_worker"] = Get-NullStr $r.assigned_social_worker
    $dr["initial_case_assessment"] = Get-NullStr $r.initial_case_assessment
    $v = Get-NullDate $r.date_case_study_prepared
    if ($v -is [DateTime]) { $dr["date_case_study_prepared"] = $v } else { $dr["date_case_study_prepared"] = [DBNull]::Value }
    $dr["reintegration_type"] = Get-NullStr $r.reintegration_type
    $dr["reintegration_status"] = Get-NullStr $r.reintegration_status
    $dr["initial_risk_level"] = Get-NullStr $r.initial_risk_level
    $dr["current_risk_level"] = Get-NullStr $r.current_risk_level
    $v = Get-NullDate $r.date_enrolled
    if ($v -is [DateTime]) { $dr["date_enrolled"] = $v } else { $dr["date_enrolled"] = [DBNull]::Value }
    $v = Get-NullDate $r.date_closed
    if ($v -is [DateTime]) { $dr["date_closed"] = $v } else { $dr["date_closed"] = [DBNull]::Value }
    $v = Get-NullDateTime $r.created_at
    if ($v -is [DateTime]) { $dr["created_at"] = $v } else { $dr["created_at"] = [DBNull]::Value }
    $dr["notes_restricted"] = Get-NullStr $r.notes_restricted
    $dt.Rows.Add($dr)
}

$conn = New-Object System.Data.SqlClient.SqlConnection $cs
$conn.Open()
try {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = @"
DELETE FROM dbo.incident_reports;
DELETE FROM dbo.residents;
"@
    $cmd.ExecuteNonQuery() | Out-Null
    Write-Host "Cleared dbo.incident_reports and dbo.residents (CASCADE removes other child rows tied to residents)."

    $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($conn)
    $bulk.DestinationTableName = "dbo.residents"
    $bulk.BatchSize = 50
    $bulk.BulkCopyTimeout = 120
    foreach ($c in $dt.Columns) {
        [void]$bulk.ColumnMappings.Add($c.ColumnName, $c.ColumnName)
    }
    $bulk.WriteToServer($dt)
    Write-Host "Loaded $($dt.Rows.Count) rows into dbo.residents."
}
finally {
    $conn.Close()
}

Write-Host 'Done. Reload child tables (education, health, incidents, etc.) if needed; they were removed with residents.'
Write-Host 'VERIFY: SELECT COUNT(*) FROM dbo.residents; expect 60 rows.'
