# keeper

## Dev setup

```bash
# Optional: Postgres (other tooling / ML — not used by the .NET API)
docker compose up -d

# Frontend setup
cd web
bun i
bun dev

# Backend (Azure SQL via EF Core — connection string must not be committed)

cd api/src

# One-time: store the Azure SQL connection string in user secrets (recommended)
dotnet user-secrets set ConnectionStrings:DefaultConnection "Server=tcp:YOUR_SERVER.database.windows.net,1433;Database=YOUR_DB;User ID=YOUR_USER;Password=YOUR_PASSWORD;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;"

dotnet run
```

### API configuration and security

- **Connection strings** live in **[User Secrets](https://learn.microsoft.com/aspnet/core/security/app-secrets)** locally (`api.csproj` already has a `UserSecretsId`) or in **environment variables**. The repo keeps **`appsettings.json`** with an **empty** `DefaultConnection`; production uses **`ASPNETCORE_ENVIRONMENT=Production`** and **`appsettings.Production.json`** (also no secrets).
- **Azure App Service**: set **Application settings → Connection strings** → name **`DefaultConnection`**, type SQL Azure. That maps to **`ConnectionStrings__DefaultConnection`**. Prefer **Managed Identity + Azure AD** for SQL when you outgrow SQL authentication ([docs](https://learn.microsoft.com/azure/app-service/tutorial-connect-msi-sql-database)).
- **`/health`** runs a **database health check** (EF Core) and returns JSON with check status.
- **EF Core** uses **transient fault handling** (retries) for Azure SQL.

See also **`docs/import-csv-to-azure-sql.md`** for loading Lighthouse CSVs into Azure SQL (separate from the API process).

