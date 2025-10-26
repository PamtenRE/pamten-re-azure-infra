# RecruitEdge Azure Infrastructure

This repository contains the **Azure infrastructure-as-code** for the RecruitEdge platform. It uses **Bicep** templates with a manifest-driven deployment approach to manage resources across environments. The infrastructure is defined separately from application code, allowing independent deployment and management of Azure resources that support multiple application components (Java API, Python ML Engine, React frontend, etc.).

## Key Features

- **Environment-driven deployments** using GitHub Actions
- **Manifest-based resource definition** with environment variable substitution
- **Centralized tagging** through `tags.yaml` with resource-level overrides
- **Modular Bicep templates** for each Azure service type
- **Comprehensive resource tracking** with deployment reports

## Why use Bicep?

Bicep is Azure’s native domain‑specific language for ARM templates.  It provides a concise declarative syntax and integrates seamlessly with Azure tooling.  Unlike Terraform, Bicep does not require a state file; Azure manages the state for you【384619449186889†L156-L178】.  Bicep supports parameters and loops so you can create multiple instances of a resource by passing an array or count at deployment time【384619449186889†L140-L149】.  Because this project targets Azure exclusively, Bicep is the simplest and most natural choice.

## Repository Structure

```
recruitedge-azure-infra/
├── envs/                   # Environment-specific deployments
│   ├── dev/
│   │   ├── main.bicep     # Entry point for dev environment
│   │   └── parameters.yaml # Dev environment parameters
│   └── prod/
│       ├── main.bicep     # Entry point for prod environment
│       └── parameters.yaml # Prod environment parameters
├── templates/             # Modular Bicep templates by service
│   ├── api-management/    # API Management gateway
│   ├── app-service/      # App Service for Java/Python backends
│   ├── azure-ad-b2c/     # B2C tenant for authentication
│   ├── azure-functions/  # Function Apps (Python/Node)
│   │   ├── template.bicep # Function App definition
│   │   └── template.yml  # Reusable GitHub Actions workflow
│   ├── sql/             # SQL Server and database
│   ├── static-web/      # Static web hosting for React frontend
│   └── storage/         # Shared storage accounts
├── manifest.yaml         # Unified resource manifest for all environments
├── tags.yaml            # Global tagging strategy and definitions
├── scripts/
│   ├── deploy_from_manifest.py  # Deployment orchestration
│   └── tests/          # Script testing
├── docs/
│   └── naming-conventions.md  # Resource naming standards
└── README.md
```

### Core Components

#### manifest.yaml

The central configuration file that defines all infrastructure resources across environments. Key features:
- Environment variable substitution (e.g., `${ENVIRONMENT}`, `${SQL_ADMIN_PWD}`)
- Centralized resource definition with template references
- Component-specific tagging with global tag inheritance
- Structured sections for different application components (APIs, Functions, Web)

#### templates/

Modular Bicep templates organized by Azure service type:
- `api-management/` - API Gateway for service management
- `app-service/` - App Services for Java and Python backends
- `azure-ad-b2c/` - Authentication and identity management
- `azure-functions/` - Serverless Functions (Python for ML, Node for webhooks)
- `sql/` - Database infrastructure
- `static-web/` - Static hosting for React frontend
- `storage/` - Shared storage resources

### templates/

The `templates` directory contains **service‑specific Bicep files**.  Each template defines a single Azure resource: a storage account, SQL server/database, Web App or Function App.  They accept parameters such as `name`, `location`, `skuName` and `runtime`.  These templates are reusable—you can deploy them individually via the Azure CLI or as part of an environment.  Under `templates/azure‑functions` there is also a `template.yml` file: this is a *reusable GitHub Actions workflow* that logs into Azure and deploys the corresponding Bicep template.  You might use it if you want to deploy a Function App from a separate repository.  It is optional; if you rely on the manifest‑driven deployment described below, you can ignore or remove it.

### manifest.yml and tags.yaml

`manifest.yml` provides a **declarative list of resources** to deploy for each environment (`dev` and `prod`).  Each entry specifies a `template` (e.g. `azure‑functions`, `app‑service`) and a `variables` section mapping to the template’s parameters (name, location, SKU, etc.).  You no longer need to repeat tags in every entry.  Instead, tags are defined centrally in `tags.yaml`:

```yaml
dev:
  Environment: dev
  Project: job-portal
  Owner: platform-team

prod:
  Environment: prod
  Project: job-portal
  Owner: platform-team
```

When `scripts/deploy_from_manifest.py` runs, it loads the tags for the selected environment from `tags.yaml` and applies them to **every resource**.  If you need to override or add tags for a single resource, you can still include a `tags` dictionary in that resource’s `variables`.  The script merges the environment‑level tags and resource‑level tags, giving precedence to the resource‑level keys.

### scripts/

The `deploy_from_manifest.py` script is the heart of the manifest‑driven deployment.  It reads `manifest.yml`, substitutes any `${VAR}` placeholders with environment variables (e.g. `SQL_ADMIN_USER` and `SQL_ADMIN_PWD`), merges tags from `tags.yaml`, and invokes the Azure CLI to deploy each resource.  This approach lets you maintain a **single manifest** and centralise tagging while still supporting resource‑specific overrides.

## Deployment Guide

### Prerequisites

1. **Azure Credentials**
   Required secrets in GitHub Actions:
   ```yaml
   AZURE_CLIENT_ID: <service-principal-id>
   AZURE_TENANT_ID: <tenant-id>
   AZURE_SUBSCRIPTION_ID: <subscription-id>
   SQL_ADMIN_USER: <database-admin>
   SQL_ADMIN_PWD: <database-password>
   ```

2. **Environment Setup**
   - Ensure Python 3.x is installed
   - Install dependencies: `pip install pyyaml`
   - Azure CLI with authenticated session

### Deployment Methods

#### 1. GitHub Actions (Recommended)

Push to designated branches triggers automatic deployment:
- `develop` branch → dev environment
- `master` branch → prod environment

The workflow:
1. Sets environment based on branch
2. Authenticates with Azure
3. Runs deployment script with appropriate parameters

#### 2. Manual Deployment

Local deployment for testing or emergency fixes:

```powershell
# Set environment variables
$env:ENVIRONMENT = "dev"  # or "prod"
$env:SQL_ADMIN_USER = "admin"
$env:SQL_ADMIN_PWD = "password"

# Run deployment
python scripts/deploy_from_manifest.py --manifest manifest.yaml --env $env:ENVIRONMENT
```

### Deployment Validation

1. Check the deployment report in `deployment_report.json`
2. Verify resources in Azure Portal
3. Test component connectivity
4. Review applied tags

5. **(Optional) Use the reusable workflow**.  If you prefer to deploy a Function App as part of another repository’s CI pipeline, you can call `templates/azure‑functions/template.yml` as a reusable workflow.  It expects inputs such as the function name, location, runtime and resource group, and deploys the Function App using the Bicep template.  However, if you adopt the manifest‑driven approach above, this workflow is not required.

## Frequently asked questions

**Why are there both `template.bicep` and `template.yml` files under `templates/azure‑functions`?**  
`template.bicep` defines the infrastructure for a Function App (plan and function).  It is used by the manifest‑driven deployment and can be deployed directly via the Azure CLI.  `template.yml` is a reusable GitHub Actions workflow that wraps the Bicep deployment; it makes it easy to call the Function deployment from another pipeline.  You can delete `template.yml` if you are not using it.

**How do tags work now?**  
Instead of specifying tags in every resource entry within `manifest.yml`, you define them once in `tags.yaml` under `dev` and `prod`.  The deploy script reads these tags and attaches them to each resource automatically.  If you need to override a tag for a single resource, include a `tags` dictionary in that resource’s `variables`—these values will override the environment‑level tags.

**Can I still use loops to create multiple resources?**  
Yes.  In the environment templates (`envs/dev/main.bicep` and `envs/prod/main.bicep`), loops are driven by parameters such as `webCount`, `storageCount` and `functionCount`.  Set these counts in `parameters.dev.json` or `parameters.prod.json` to create multiple instances of Web Apps, Storage accounts or Function Apps【384619449186889†L140-L149】.

## Conclusion

This repository focuses on Azure Bicep and simple manifest‑driven deployments.  By separating resource definitions (templates), environment configuration (`envs`), global tags (`tags.yaml`) and declarative manifests (`manifest.yml`), you can build, manage and scale your infrastructure cleanly.  Feel free to extend the templates or add new ones as your application evolves, and keep your tags consistent across resources using the central `tags.yaml` file.