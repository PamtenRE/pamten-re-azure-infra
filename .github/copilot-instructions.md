# AI Agent Instructions for pamten-re-azure-infra

This repository manages Azure infrastructure for the job-portal project using Bicep templates and a manifest-driven deployment pipeline. The notes below focus on repository-specific conventions an AI agent must follow to be productive immediately.

## Quick summary

- Environments are under `envs/<env>/` and each has `main.bicep` as the entry point.
- Canonical environment parameters file: `envs/<env>/parameters.yaml` — a simple YAML mapping of parameter names to values. The deploy script converts this to the Azure parameter JSON shape at runtime.
- Deployments are driven by `manifest.yaml` and executed by `scripts/deploy_from_manifest.py` which maps short template keys (see `TEMPLATE_PATHS`) to Bicep template files in `templates/`.

## Parameters and secrets

- Use `envs/<env>/parameters.yaml` for environment configuration. Example:

  ```yaml
  environment: dev
  location: eastus
  administratorLogin: sqladmin
  administratorPassword: ${SQL_ADMIN_PWD}
  ```

- The deploy script substitutes `${VAR}` placeholders with environment variables (CI should provide `SQL_ADMIN_USER` and `SQL_ADMIN_PWD`).

## Branch/CI behavior

- CI invokes:
  ```powershell
  python3 scripts/deploy_from_manifest.py --manifest manifest.yaml --env "$ENVIRONMENT" --branch "${{ github.ref }}"
  ```
- If `--branch` is provided the script normalizes the ref by taking the last path segment (e.g. `refs/heads/feature/foo` -> `feature/foo`) and will look for `envs/<branch_short>/parameters.yaml` first. If none exists it falls back to `envs/<env>/parameters.yaml`.
- Note: we intentionally do not implement implicit mappings (branch -> environment); if you need that mapping, request it explicitly.

## Deployment details (practical rules)

- The script creates a temporary Azure parameters JSON file from the YAML mapping and passes it to the az CLI with `--parameters @file`.
- Inline parameters constructed from `manifest.yaml` are appended after the file parameters and therefore override values in the file.
- Tags: env-level tags are loaded from `tags.yaml`; resource-level tags in the manifest override env tags.

## Common tasks

- Add a new template:
  1. Add `templates/<name>/template.bicep`.
  2. Add an entry to `TEMPLATE_PATHS` in `scripts/deploy_from_manifest.py`.
  3. Add a resource entry in `manifest.yaml`.

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
