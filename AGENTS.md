## Tech Stack

- C# with Dotnet 10 hosted on Azure
  - Linq & Entity Framework Core for DB querying
- React + Vite hosted on Vercel
  - Shadcn components
- Postgres 16 in Docker (dev) / AzureSQL (prod)
- FastAPI machine learning pipeline

## Important notes

- The machine learning pipeline must be available via FastAPI
- The DotNet backend will be a proxy for the FastAPI api between the database
  and the API itself. All data will be piped to and from the FastAPI api via
  dotnet.
