# Naming and Tagging Conventions

Consistent naming and tagging make it easier to locate and manage resources across environments【266227629141314†screenshot】.  This repository follows the conventions below:

## Resource names

| Component | Pattern | Example |
|-----------|--------|---------|
| Resource group | `jobportal-<env>-rg` | `jobportal-dev-rg` |
| Storage account | `jobportal<env>sa` (must be globally unique, no hyphens) | `jobportaldevsa` |
| SQL server | `jobportal-<env>-sqlsrv` | `jobportal-prod-sqlsrv` |
| SQL database | `jobportal-<env>-db` | `jobportal-dev-db` |
| App Service plan | `jobportal-<env>-plan` | `jobportal-prod-plan` |
| Web App | `jobportal-<env>-web` | `jobportal-dev-web` |
| Function App | `jobportal-<env>-func` | `jobportal-prod-func` |

The `<env>` placeholder should be replaced with the environment name, such as `dev` or `prod`.  Resource names should be lowercase and may need to adhere to Azure’s naming rules (e.g., storage account names allow only letters and numbers).

## Tags

Apply a consistent set of tags across all resources to support cost management, organization and automation【266227629141314†screenshot】:

- `Environment`: `dev` or `prod`
- `Project`: `job-portal`
- `Owner`: the team or individual responsible for the resource
- Additional tags as required (e.g., `CostCenter`, `Department`)

Tags are defined centrally in the environment templates and passed down to modules.