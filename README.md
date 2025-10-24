# Pamten‑re Azure Infrastructure

This repository contains the **Azure‑only infrastructure‑as‑code** for the Pamten job‑portal platform.  It uses **Bicep** to define resources and a simple Python helper to deploy them.  The goal is to keep infrastructure and application code separate: this repo provisions Azure resources while the application repos (e.g. `backend‑java`, `backend‑python` and `react`) publish their own code.  By isolating infrastructure here, multiple team members can collaborate on the IaC without interfering with application development.

## Why use Bicep?

Bicep is Azure’s native domain‑specific language for ARM templates.  It provides a concise declarative syntax and integrates seamlessly with Azure tooling.  Unlike Terraform, Bicep does not require a state file; Azure manages the state for you【384619449186889†L156-L178】.  Bicep supports parameters and loops so you can create multiple instances of a resource by passing an array or count at deployment time【384619449186889†L140-L149】.  Because this project targets Azure exclusively, Bicep is the simplest and most natural choice.

## Repository structure

```
pamten‑re‑azure‑infra/
├── envs/                   # Environment‑specific deployments
│   ├── dev/
│   │   ├── main.bicep       # Entry point for dev environment
│   │   └── parameters.dev.json  # Parameters for dev (names, SKUs, counts)
│   └── prod/
│       ├── main.bicep       # Entry point for prod environment
│       └── parameters.prod.json  # Parameters for prod
├── templates/              # Service‑specific templates and optional workflow
│   ├── azure‑functions/
│   │   ├── template.bicep   # Deploy a Function App (infrastructure only)
│   │   └── template.yml     # Optional reusable GitHub Actions workflow for deploying the Function template
│   ├── app‑service/
│   │   └── template.bicep   # Deploy a Web App and plan
│   ├── sql/
│   │   └── template.bicep   # Deploy a SQL server and database
│   └── storage/
│       └── template.bicep   # Deploy a Storage account
├── manifest.yml            # Single manifest listing resources to deploy in each environment
├── tags.yaml               # Central definition of tags for dev and prod environments
├── scripts/
│   └── deploy_from_manifest.py  # Helper script to parse manifest and deploy resources
├── docs/
│   └── naming-conventions.md   # Naming and tagging guidelines
└── README.md                  # This file
```

### envs/

Environment folders contain **entry point** Bicep files (`main.bicep`) that assemble one or more templates into a complete environment.  The accompanying parameter files (`parameters.dev.json`, `parameters.prod.json`) define values for resource names, SKUs and counts.  Because Bicep loops must know their length at deployment time, you set counts (e.g. number of Function Apps) in these parameter files【384619449186889†L140-L149】.  Adjusting the counts lets you scale your environment without modifying the Bicep code.

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

## How to deploy

1. **Set up credentials**.  In your CI environment (e.g. GitHub Actions), define secrets for `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `SQL_ADMIN_USER` and `SQL_ADMIN_PWD`.  These are required by the script and any workflows that call it.

2. **Adjust `parameters.dev.json` and `parameters.prod.json`** for environment‑specific names, SKUs, locations and counts.  Follow the naming guidelines in `docs/naming-conventions.md` for consistency.

3. **Edit `manifest.yml`** to list the resources you want for each environment.  Use the `template` keys from the `templates` directory and provide only the necessary parameters.  You no longer need to include tags here unless you want to override values from `tags.yaml`.

4. **Run the helper script** locally or in a CI workflow:

   ```bash
   # Example: deploy dev environment
   python scripts/deploy_from_manifest.py --manifest manifest.yml --env dev

   # Example: deploy prod environment
   python scripts/deploy_from_manifest.py --manifest manifest.yml --env prod
   ```

   The script will iterate through the resources in the selected environment, apply the tags from `tags.yaml`, substitute environment variables, and call `az deployment group create` for each template.

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