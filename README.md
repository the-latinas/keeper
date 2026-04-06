# keeper

## Dev setup

```bash
# DB setup
docker compose up -d
./scripts/migrate.sh

# Frontend setup
cd web
bun i
bun dev

# Backend setup

cd api/src
dotnet run .
```

