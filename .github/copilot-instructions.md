# AI Agent Instructions for RecruitEdge Infrastructure

This repository manages the Azure infrastructure for the RecruitEdge platform using a manifest-driven approach with Bicep templates. The instructions below cover key conventions and patterns that an AI agent should follow.

## Core Concepts

### Manifest-Driven Deployment
- All resources are defined in `manifest.yaml`
- Resources are grouped by type (storage, functions, web apps, etc.)
- Environment-specific values use `${ENVIRONMENT}` substitution
- Global tags from `tags.yaml` are automatically applied

### Template Structure
- Modular Bicep templates in `templates/` directory
- Each service type has its own template:
  - `api-management/` - API Gateway
  - `app-service/` - Web backends
  - `azure-functions/` - Serverless components
  - `sql/` - Database resources
  - `static-web/` - Frontend hosting
  - `storage/` - Shared storage

### Variable Substitution

The deployment system supports dynamic configuration through environment variables:

```yaml
# Example manifest entry
- template: sql
  variables:
    serverName: "recruitedge-${ENVIRONMENT}-sqlsrv"
    databaseName: "recruitedge-${ENVIRONMENT}-db"
    administratorLogin: ${SQL_ADMIN_USER}
    administratorPassword: ${SQL_ADMIN_PWD}
```

Required environment variables:
- `ENVIRONMENT`: Sets deployment target (dev/prod)
- `SQL_ADMIN_USER`: Database administrator username
- `SQL_ADMIN_PWD`: Database administrator password
- Azure credentials (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`)

### Tagging System

Global tags are defined in `tags.yaml`:
```yaml
global:
  applicationId: jobportal
  environment: ${ENVIRONMENT}
  costCenter: FIN-2025
  rsm: vinay.bhavanam@pamten.com
  managedBy: Pamten CloudOps
  # ... other tags
```

Resource-specific tags can be added in the manifest:
```yaml
- template: app-service
  variables:
    name: "recruitedge-${ENVIRONMENT}-java-api"
    tags:
      app: recruit-edge-api
      runtime: java
      tier: backend
```

The deployment script:
1. Validates required tags exist
2. Merges global and resource-specific tags
3. Applies final tag set to each resource

### Common Development Tasks

#### Adding New Resources

1. Create Bicep Template:
   ```bicep
   // templates/new-service/template.bicep
   param name string
   param location string
   param tags object = {}
   // ... resource definition
   ```

2. Add Template Path:
   ```python
   # In scripts/deploy_from_manifest.py
   template_paths = {
     'new-service': 'templates/new-service/template.bicep',
     # ... other templates
   }
   ```

3. Add to Manifest:
   ```yaml
   - template: new-service
     variables:
       name: "recruitedge-${ENVIRONMENT}-newservice"
       location: eastus
       # ... other parameters
   ```

#### Updating Environments

1. Modify parameters in `envs/<env>/parameters.yaml`
2. Update resource configuration in manifest
3. Test locally before pushing:
   ```powershell
   $env:ENVIRONMENT="dev"
   python scripts/deploy_from_manifest.py --manifest manifest.yaml --env $env:ENVIRONMENT
   ```

## Key files

- `scripts/deploy_from_manifest.py` — deployment logic and parameter conversion.
- `manifest.yaml` — top-level manifest used by CI to describe resources per environment.
- `envs/<env>/parameters.yaml` — canonical per-environment parameters.
- `docs/naming-conventions.md` — naming and tagging guidance used across templates.

If you want more detail on any workflow or a sample manifest for a new resource, tell me which resource and I will add a focused example.
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
