# Dot-source this so sqlcmd/bcp see AZURE_SQL_* in the same session:
#   cd ...\keeper\scripts
#   . .\Load-KeeperEnv.ps1
# PowerShell 5.1 Join-Path accepts only two segments; chain for ..\.env
$envFile = Join-Path (Join-Path $PSScriptRoot '..') '.env'
$envFile = (Resolve-Path -LiteralPath $envFile -ErrorAction Stop).Path
Get-Content -LiteralPath $envFile | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
    [Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim(), 'Process')
  }
}
Write-Host "Loaded $envFile"
Write-Host "  AZURE_SQL_SERVER=$env:AZURE_SQL_SERVER"
Write-Host "  AZURE_SQL_DATABASE=$env:AZURE_SQL_DATABASE"
