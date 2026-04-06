# Import Lighthouse CSVs into Azure SQL

How to load **lighthouse_csv_v7**-style CSVs into **Azure SQL**. This doc is the checklist and mental model; per-table `sqlcmd` / `bcp` lines can be generated for your paths when you need them.

## Idea

1. **`stg` schema** — hold raw text from files.
2. **`stg.<name>_raw`** — one column per **CSV header** (same names, snake_case), mostly `NVARCHAR` / `NVARCHAR(MAX)` for long text.
3. **`bcp`** — load the file into that staging table (UTF-8, comma field delimiter, pick row terminator that matches the file—LF vs CRLF).
4. **Remove the header row** from staging (`DELETE … WHERE <pk_column> = '<header_label>'`).
5. **`INSERT INTO dbo.<table> … SELECT … FROM stg…`** — use `TRY_CAST`, `NULLIF`, and for `True`/`False` strings use a `CASE` → `bit` pattern.
6. **`SELECT COUNT(*)`** — compare to “CSV lines − 1”.

Do **not** commit real production passwords. For local imports, keep secrets in **`keeper/.env`** (already **gitignored**). Copy **`keeper/.env.example`** → **`keeper/.env`** and fill in values.

## Prerequisites

- Azure SQL server + database; firewall allows your IP.
- `sqlcmd` and `bcp` installed.
- Credentials from Azure Portal (server FQDN, database name, SQL admin user), stored in **`keeper/.env`** as `AZURE_SQL_SERVER`, `AZURE_SQL_DATABASE`, `AZURE_SQL_USER`, `AZURE_SQL_PASSWORD`.

### Load `.env` in PowerShell (once per terminal session)

**You must load `.env` before `sqlcmd` / scripts see `$env:AZURE_SQL_*`.** If those variables are empty, `sqlcmd` may prompt for `Password:` or fail with confusing parse errors when `-S` / `-d` are effectively empty.

**Option A — from repo root (`keeper`):**

```powershell
Set-Location <path-to-repo>\keeper
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
    [Environment]::SetEnvironmentVariable($matches[1], $matches[2].Trim(), 'Process')
  }
}
```

**Option B — from `keeper\scripts` (loads `keeper\.env` one folder up):**

```powershell
Set-Location <path-to-repo>\keeper\scripts
. .\Load-KeeperEnv.ps1
```

Then use **`$env:AZURE_SQL_PASSWORD`** (and the other `AZURE_SQL_*` vars) in `sqlcmd` / `bcp` instead of pasting `-P` each time. Example fragment:

```powershell
sqlcmd -S $env:AZURE_SQL_SERVER -d $env:AZURE_SQL_DATABASE -U $env:AZURE_SQL_USER -P $env:AZURE_SQL_PASSWORD -N -C -Q "SELECT 1"
```

## Load order (foreign keys)

Follow this order so parent rows exist before children. It matches **`api/src/Data/AppDbContext.cs`** (FKs and table names). Notable constraint: **`donations.referral_post_id`** is optional but references **`social_media_posts`**, so load **`social_media_posts` before `donations`**.

1. `safehouses`
2. `partners`
3. `supporters`
4. `social_media_posts` (special case — see below; must be before `donations` if you use `referral_post_id`)
5. `residents`
6. `donations`
7. `in_kind_donation_items`
8. `donation_allocations`
9. `partner_assignments`
10. `incident_reports`
11. `education_records`
12. `health_wellbeing_records`
13. `intervention_plans`
14. `process_recordings`
15. `home_visitations`
16. `safehouse_monthly_metrics`
17. `public_impact_snapshots`

## Each “simple” table (most CSVs)

- Create `stg.<table>_raw` if it doesn’t exist (drop/recreate when column set changes).
- `DELETE FROM dbo.<table>` when safe to wipe (if other tables reference this table, clear **children** first).
- Run `bcp` into `stg.<table>_raw` with `-c -C 65001 -t "," -r <LF or CRLF> -F 1` and `-e` error file.
- Delete the header row from staging.
- Insert into `dbo.<table>` with typed `SELECT` from staging.
- Verify row count.

**`bcp` flags to remember:** `-d <database>` on `bcp`, `-N -C` on `sqlcmd` for Azure. If **0 rows copied**, switch row terminator (`0x0A` vs `"\r\n"`).

## Special cases

- **`social_media_posts`** — commas appear **inside quoted fields**; plain comma-only `bcp` is unreliable. Use the repo script **`scripts/Import-SocialMediaPosts.ps1`** (`Import-Csv` + `SqlBulkCopy`), or SSMS/Azure Data Studio import, or another RFC-4180-aware tool. **Load `keeper/.env` first** (see above) so the script can use `AZURE_SQL_*`, or pass `-Server`, `-Database`, `-User`, and `-Password` explicitly.
- **`process_recordings`** — quoted **`interventions_applied`** values contain commas (e.g. `"Healing, Legal Services"`); `bcp` mis-splits rows → `process_recordings_bcp_errors.txt` truncation warnings. Use **`scripts/Import-ProcessRecordings.ps1`** instead (`Import-Csv` + `SqlBulkCopy` into `dbo.process_recordings`).
- **`public_impact_snapshots`** — **`summary_text`** and **`metric_payload_json`** are quoted and contain commas; `bcp` mis-splits → `public_impact_snapshots_bcp_errors.txt`. Use **`scripts/Import-PublicImpactSnapshots.ps1`** (`Import-Csv` + `SqlBulkCopy`).
- **`residents`** — staging with **`NVARCHAR(20)`** on boolean/subcategory columns truncates the **CSV header** (e.g. **`sub_cat_physical_abuse`** is 22 chars) → `residents_bcp_errors.txt`. Either widen those staging columns to **`NVARCHAR(100)`+**, or use **`scripts/Import-Residents.ps1`** (`Import-Csv` + `SqlBulkCopy`). **Warning:** that script **`DELETE`s `incident_reports` then `residents`** (CASCADE removes other child rows); re-import dependent tables afterward if you replace data mid-project.
- **`partner_assignments.safehouse_id`** — values like `8.0` may need `CAST(TRY_CAST(safehouse_id AS FLOAT) AS INT)` (or similar) in the `INSERT`.
- **`residents`** — many boolean columns from `True`/`False`; same staging + `bcp` pattern, but the final `INSERT` needs a `CASE` per boolean column. If child tables already have data, delete children before re-importing `residents`.

## Troubleshooting

| Symptom | What to try |
|--------|-------------|
| `0 rows copied` | Wrong row terminator; try `\r\n` vs `\n` |
| Login failed | Password, firewall, server name |
| Insert type errors | Widen staging text columns; fix `TRY_CAST` / `CASE` |
| Wrong column count | Staging columns must match CSV header count and order |

## Table ↔ file map

| CSV file | `dbo` table |
|----------|-------------|
| `safehouses.csv` | `safehouses` |
| `partners.csv` | `partners` |
| `supporters.csv` | `supporters` |
| `social_media_posts.csv` | `social_media_posts` |
| `residents.csv` | `residents` |
| `donations.csv` | `donations` |
| `in_kind_donation_items.csv` | `in_kind_donation_items` |
| `donation_allocations.csv` | `donation_allocations` |
| `partner_assignments.csv` | `partner_assignments` |
| `incident_reports.csv` | `incident_reports` |
| `education_records.csv` | `education_records` |
| `health_wellbeing_records.csv` | `health_wellbeing_records` |
| `intervention_plans.csv` | `intervention_plans` |
| `process_recordings.csv` | `process_recordings` |
| `home_visitations.csv` | `home_visitations` |
| `safehouse_monthly_metrics.csv` | `safehouse_monthly_metrics` |
| `public_impact_snapshots.csv` | `public_impact_snapshots` |

Column names and `dbo.<table>` names match **`api/src/Data/AppDbContext.cs`** (`ToTable(...)` and `HasColumnName(...)`; snake_case in SQL).

## Where automation lives

- **`keeper/scripts/Import-SocialMediaPosts.ps1`** — `social_media_posts` only (RFC-4180 CSV + bulk insert).
- **`keeper/scripts/Import-ProcessRecordings.ps1`** — `process_recordings` (same pattern; replaces unreliable `bcp` for that file).
- **`keeper/scripts/Import-PublicImpactSnapshots.ps1`** — `public_impact_snapshots` (same pattern).
- **`keeper/scripts/Import-Residents.ps1`** — `residents` (RFC-4180-safe; destructive: clears `incident_reports` + `residents` and cascaded children — see script header).
- **`keeper/scripts/Load-KeeperEnv.ps1`** — loads **`keeper/.env`** into the current PowerShell session.
