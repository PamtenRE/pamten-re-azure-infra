# AI Agent Instructions for pamten-re-azure-infra

This repository contains Azure infrastructure as code using Bicep templates for a job portal application. Here's what you need to know to effectively work with this codebase:

## Architecture Overview

- Multi-environment infrastructure (dev/prod) defined in `envs/<env>/main.bicep`
- Modular Bicep templates in `templates/` for key components:
  - Storage accounts
  - SQL Server/Database
  - App Service (Web Apps)
  - Azure Functions
- Deployment orchestration via GitHub Actions using Python-based manifest deployment

## Key Patterns and Conventions

### Resource Naming

Resource names follow strict patterns defined in `docs/naming-conventions.md`:
```
<project>-<env>-<resource-type>    # Example: jobportal-dev-web
<project><env>sa                   # Storage accounts (no hyphens)
```

### Tagging Strategy

Every resource must have these tags (defined in environment templates):
- `Environment`: `dev` or `prod`
- `Project`: `recruit-edge`

### Manifest-Based Deployment

Deployments use YAML manifests that:
1. Define environment-specific resources
2. Support environment variable substitution (`${VAR_NAME}`)
3. Allow resource-level tag overrides

Example deployment command:
```powershell
python scripts/deploy_from_manifest.py --manifest manifest.yml --env dev
```

## Critical Workflows

### Infrastructure Deployment

1. Changes to `develop` branch deploy to dev environment
2. Changes to `master` branch deploy to prod environment
3. Deployment requires these secrets:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `SQL_ADMIN_USER`
   - `SQL_ADMIN_PWD`

### Development Workflow

1. Create/modify Bicep templates in `templates/`
2. Update environment configuration in `envs/<env>/`
3. Define resources in manifest file
4. Test locally using Azure CLI
5. Push to appropriate branch for deployment

## Common Tasks

### Adding New Resources

1. Create template in `templates/<resource-type>/template.bicep`
2. Add template path to `TEMPLATE_PATHS` in `deploy_from_manifest.py`
3. Reference template in environment's `main.bicep`
4. Add resource entry to manifest file

### Environment Configuration

Parameters in `envs/<env>/parameters.<env>.json` control:
- Resource SKUs/tiers
- Region placement
- Environment-specific settings

## Key Files

- `.github/workflows/deploy.yml`: CI/CD pipeline configuration
- `scripts/deploy_from_manifest.py`: Deployment orchestration script
- `envs/<env>/main.bicep`: Environment entry points
- `docs/naming-conventions.md`: Resource naming rules
