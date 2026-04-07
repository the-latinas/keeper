#requires -Version 5.1
<#
  Loads lighthouse_csv_v7/social_media_posts.csv into dbo.social_media_posts.
  Uses Import-Csv (RFC4180 / quoted commas) + SqlBulkCopy — plain bcp cannot split this file reliably.

  Usage (recommended — load keeper/.env first):
    cd ...\keeper\scripts
    . .\Load-KeeperEnv.ps1
    .\Import-SocialMediaPosts.ps1

  Or pass connection info explicitly (do not commit real values):
    .\Import-SocialMediaPosts.ps1 -Server 'yourserver.database.windows.net' -Database 'your-db' -User 'youruser' -PlainPassword '...'

  Do not commit passwords or run this from an untrusted copy-paste log.
#>
param(
    [string] $Server = $env:AZURE_SQL_SERVER,
    [string] $Database = $env:AZURE_SQL_DATABASE,
    [string] $User = $env:AZURE_SQL_USER,
    [Security.SecureString] $Password,
    [string] $PlainPassword,
    [string] $CsvPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Server)) {
    throw "Server not set. Run '. .\Load-KeeperEnv.ps1' from keeper\scripts (with keeper\.env filled) or pass -Server."
}
if ([string]::IsNullOrWhiteSpace($Database)) {
    throw "Database not set. Run '. .\Load-KeeperEnv.ps1' or pass -Database."
}
if ([string]::IsNullOrWhiteSpace($User)) {
    throw "User not set. Run '. .\Load-KeeperEnv.ps1' or pass -User."
}

if (-not $CsvPath) {
    $CsvPath = Join-Path (Split-Path $PSScriptRoot -Parent) "lighthouse_csv_v7\social_media_posts.csv"
}
if (-not (Test-Path -LiteralPath $CsvPath)) {
    throw "CSV not found: $CsvPath"
}

$pwdPlain = $null
if ($PlainPassword) { $pwdPlain = $PlainPassword }
elseif ($Password) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    try { $pwdPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}
elseif (-not [string]::IsNullOrWhiteSpace($env:AZURE_SQL_PASSWORD)) {
    $pwdPlain = $env:AZURE_SQL_PASSWORD
}
else {
    $sec = Read-Host -AsSecureString "SQL password"
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $pwdPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$cs = "Server=tcp:$Server,1433;Database=$Database;User ID=$User;Password=$pwdPlain;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;"

function Get-DbNullStr([string] $s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    return $s
}
function Get-DbNullInt([string] $s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    $t = $s.Trim()
    $n = 0
    if ([int]::TryParse($t, [ref]$n)) { return $n }
    $d = 0.0
    if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$d)) {
        return [int][Math]::Round($d)
    }
    return [DBNull]::Value
}
function Get-DbNullDec([string] $s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    [decimal]$d = 0
    if ([decimal]::TryParse($s.Trim(), [ref]$d)) { return $d }
    return [DBNull]::Value
}
function Get-DbNullDbl([string] $s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    $d = 0.0
    if ([double]::TryParse($s.Trim(), [ref]$d)) { return $d }
    return [DBNull]::Value
}
function Get-DbNullBool([string] $s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return [DBNull]::Value }
    $t = $s.Trim()
    if ($t -in @("True", "true", "1")) { return $true }
    if ($t -in @("False", "false", "0")) { return $false }
    return [DBNull]::Value
}
function Get-ReqDateTime([string] $s) {
    if ([string]::IsNullOrWhiteSpace($s)) { throw "Empty created_at" }
    try {
        return [DateTime]::Parse($s.Trim(), [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AllowWhiteSpaces)
    } catch {
        throw "Bad created_at: $s"
    }
}

Add-Type -AssemblyName System.Data

$dt = New-Object System.Data.DataTable
$cols = @(
    @{ n = "post_id"; t = [int] }
    @{ n = "platform"; t = [string] }
    @{ n = "platform_post_id"; t = [string] }
    @{ n = "post_url"; t = [string] }
    @{ n = "created_at"; t = [datetime] }
    @{ n = "day_of_week"; t = [string] }
    @{ n = "post_hour"; t = [int] }
    @{ n = "post_type"; t = [string] }
    @{ n = "media_type"; t = [string] }
    @{ n = "caption"; t = [string] }
    @{ n = "hashtags"; t = [string] }
    @{ n = "num_hashtags"; t = [int] }
    @{ n = "mentions_count"; t = [int] }
    @{ n = "has_call_to_action"; t = [bool] }
    @{ n = "call_to_action_type"; t = [string] }
    @{ n = "content_topic"; t = [string] }
    @{ n = "sentiment_tone"; t = [string] }
    @{ n = "caption_length"; t = [int] }
    @{ n = "features_resident_story"; t = [bool] }
    @{ n = "campaign_name"; t = [string] }
    @{ n = "is_boosted"; t = [bool] }
    @{ n = "boost_budget_php"; t = [decimal] }
    @{ n = "impressions"; t = [int] }
    @{ n = "reach"; t = [int] }
    @{ n = "likes"; t = [int] }
    @{ n = "comments"; t = [int] }
    @{ n = "shares"; t = [int] }
    @{ n = "saves"; t = [int] }
    @{ n = "click_throughs"; t = [int] }
    @{ n = "video_views"; t = [int] }
    @{ n = "engagement_rate"; t = [double] }
    @{ n = "profile_visits"; t = [int] }
    @{ n = "donation_referrals"; t = [int] }
    @{ n = "estimated_donation_value_php"; t = [decimal] }
    @{ n = "follower_count_at_post"; t = [int] }
    @{ n = "watch_time_seconds"; t = [int] }
    @{ n = "avg_view_duration_seconds"; t = [double] }
    @{ n = "subscriber_count_at_post"; t = [int] }
    @{ n = "forwards"; t = [double] }
)
foreach ($c in $cols) {
    $col = $dt.Columns.Add($c.n, $c.t)
    $col.AllowDBNull = $true
}
$dt.Columns["post_id"].AllowDBNull = $false
$dt.Columns["created_at"].AllowDBNull = $false

$rows = Import-Csv -LiteralPath $CsvPath
foreach ($r in $rows) {
    $dr = $dt.NewRow()
    $dr["post_id"] = [int]$r.post_id
    $dr["platform"] = Get-DbNullStr $r.platform
    $dr["platform_post_id"] = Get-DbNullStr $r.platform_post_id
    $dr["post_url"] = Get-DbNullStr $r.post_url
    $dr["created_at"] = Get-ReqDateTime $r.created_at
    $dr["day_of_week"] = Get-DbNullStr $r.day_of_week
    $dr["post_hour"] = Get-DbNullInt $r.post_hour
    $dr["post_type"] = Get-DbNullStr $r.post_type
    $dr["media_type"] = Get-DbNullStr $r.media_type
    $dr["caption"] = Get-DbNullStr $r.caption
    $dr["hashtags"] = Get-DbNullStr $r.hashtags
    $dr["num_hashtags"] = Get-DbNullInt $r.num_hashtags
    $dr["mentions_count"] = Get-DbNullInt $r.mentions_count
    $v = Get-DbNullBool $r.has_call_to_action
    if ($v -is [bool]) { $dr["has_call_to_action"] = $v } else { $dr["has_call_to_action"] = [DBNull]::Value }
    $dr["call_to_action_type"] = Get-DbNullStr $r.call_to_action_type
    $dr["content_topic"] = Get-DbNullStr $r.content_topic
    $dr["sentiment_tone"] = Get-DbNullStr $r.sentiment_tone
    $dr["caption_length"] = Get-DbNullInt $r.caption_length
    $v = Get-DbNullBool $r.features_resident_story
    if ($v -is [bool]) { $dr["features_resident_story"] = $v } else { $dr["features_resident_story"] = [DBNull]::Value }
    $dr["campaign_name"] = Get-DbNullStr $r.campaign_name
    $v = Get-DbNullBool $r.is_boosted
    if ($v -is [bool]) { $dr["is_boosted"] = $v } else { $dr["is_boosted"] = [DBNull]::Value }
    $vd = Get-DbNullDec $r.boost_budget_php
    if ($vd -is [decimal]) { $dr["boost_budget_php"] = $vd } else { $dr["boost_budget_php"] = [DBNull]::Value }
    $dr["impressions"] = Get-DbNullInt $r.impressions
    $dr["reach"] = Get-DbNullInt $r.reach
    $dr["likes"] = Get-DbNullInt $r.likes
    $dr["comments"] = Get-DbNullInt $r.comments
    $dr["shares"] = Get-DbNullInt $r.shares
    $dr["saves"] = Get-DbNullInt $r.saves
    $dr["click_throughs"] = Get-DbNullInt $r.click_throughs
    $dr["video_views"] = Get-DbNullInt $r.video_views
    $vd = Get-DbNullDbl $r.engagement_rate
    if ($vd -is [double]) { $dr["engagement_rate"] = $vd } else { $dr["engagement_rate"] = [DBNull]::Value }
    $dr["profile_visits"] = Get-DbNullInt $r.profile_visits
    $dr["donation_referrals"] = Get-DbNullInt $r.donation_referrals
    $vd = Get-DbNullDec $r.estimated_donation_value_php
    if ($vd -is [decimal]) { $dr["estimated_donation_value_php"] = $vd } else { $dr["estimated_donation_value_php"] = [DBNull]::Value }
    $dr["follower_count_at_post"] = Get-DbNullInt $r.follower_count_at_post
    $dr["watch_time_seconds"] = Get-DbNullInt $r.watch_time_seconds
    $vd = Get-DbNullDbl $r.avg_view_duration_seconds
    if ($vd -is [double]) { $dr["avg_view_duration_seconds"] = $vd } else { $dr["avg_view_duration_seconds"] = [DBNull]::Value }
    $dr["subscriber_count_at_post"] = Get-DbNullInt $r.subscriber_count_at_post
    $vd = Get-DbNullDbl $r.forwards
    if ($vd -is [double]) { $dr["forwards"] = $vd } else { $dr["forwards"] = [DBNull]::Value }
    $dt.Rows.Add($dr)
}

$conn = New-Object System.Data.SqlClient.SqlConnection $cs
$conn.Open()
try {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = "DELETE FROM dbo.social_media_posts;"
    $deleted = $cmd.ExecuteNonQuery()
    Write-Host "Cleared dbo.social_media_posts (rows deleted: $deleted)"

    $bulk = New-Object System.Data.SqlClient.SqlBulkCopy($conn)
    $bulk.DestinationTableName = "dbo.social_media_posts"
    $bulk.BatchSize = 500
    $bulk.BulkCopyTimeout = 120
    foreach ($c in $dt.Columns) {
        [void]$bulk.ColumnMappings.Add($c.ColumnName, $c.ColumnName)
    }
    $bulk.WriteToServer($dt)
    Write-Host "Loaded $($dt.Rows.Count) rows into dbo.social_media_posts."
}
finally {
    $conn.Close()
}

Write-Host "Done. VERIFY: SELECT COUNT(*) FROM dbo.social_media_posts;"
