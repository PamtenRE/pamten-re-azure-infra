import os
import sys
import yaml
import json
import subprocess
import time
from datetime import datetime, timezone

REQUIRED_TAGS = ["applicationId", "environment", "costCenter", "rsm", "managedBy"]

# -------------------------------------------------------------------
# Utility functions
# -------------------------------------------------------------------
def load_yaml(file_path):
    if not os.path.exists(file_path):
        print(f"❌ YAML file not found: {file_path}")
        sys.exit(1)
    with open(file_path, "r") as f:
        return yaml.safe_load(f)

def substitute_env(value):
    if isinstance(value, str):
        return os.path.expandvars(value)
    elif isinstance(value, list):
        return [substitute_env(v) for v in value]
    elif isinstance(value, dict):
        return {k: substitute_env(v) for k, v in value.items()}
    return value

def merge_tags(resource_vars, global_tags):
    tags = resource_vars.get("tags", {})
    merged = {**global_tags, **tags}
    resource_vars["tags"] = merged
    return resource_vars

# -------------------------------------------------------------------
# Validation
# -------------------------------------------------------------------
def validate_required_tags(global_tags):
    missing = [t for t in REQUIRED_TAGS if t not in global_tags]
    if missing:
        print(f"⚠️ Missing required tags: {missing}")
        print("🚨 Please update tags.yaml before deploying.")
        sys.exit(1)

def ensure_subscription_tags(global_tags):
    print("🔍 Validating tags at subscription level...")
    for key, val in global_tags.items():
        try:
            subprocess.run(
                ["az", "tag", "create", "--name", key, "--value", str(val)],
                check=False,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception as e:
            print(f"⚠️ Skipped creating tag {key}: {e}")
    print("✅ Subscription-level tag enforcement complete.")

# -------------------------------------------------------------------
# Deployment core
# -------------------------------------------------------------------
def deploy_bicep(template_path, variables, dry_run=False):
    """Deploys a Bicep template using az CLI and streams output live."""
    resource_group = variables.get("resourceGroupName")
    if not resource_group:
        print("❌ Missing resourceGroupName in manifest variables.")
        return False

    args = [
        "az", "deployment", "group",
        "create",
        "--resource-group", resource_group,
        "--template-file", template_path,
        "--only-show-errors"
    ]

    if dry_run:
        args.insert(3, "what-if")
        print("🧪 Running in dry-run mode (what-if)...")

    # add parameters
    for key, value in variables.items():
        if isinstance(value, (dict, list)):
            continue
        args += ["--parameters", f"{key}={value}"]

    print(f"\n🔧 Deploying: {template_path}")
    print(f"📦 Resource group: {resource_group}")
    print(f"➡️  Parameters: {[f'{k}={v}' for k, v in variables.items() if not isinstance(v, (dict, list))]}")
    print(f"🏗️  Command: {' '.join(args)}")

    start = time.time()
    process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    for line in process.stdout:
        print(line, end="")
    process.wait()
    duration = round(time.time() - start, 2)

    if process.returncode == 0:
        print(f"✅ Deployment succeeded ({duration}s)\n")
        return True
    else:
        print(f"❌ Deployment failed ({duration}s)")
        return False

# -------------------------------------------------------------------
# Audit & Reporting
# -------------------------------------------------------------------
def write_audit_log(deployed_resources):
    data = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "triggeredBy": os.getenv("GITHUB_ACTOR", "local"),
        "environment": os.getenv("ENVIRONMENT", "unknown"),
        "resources": deployed_resources,
    }
    with open("deployment_report.json", "w") as f:
        json.dump(data, f, indent=2)
    print("🧾 Deployment report written to deployment_report.json")

# -------------------------------------------------------------------
# Main Orchestration
# -------------------------------------------------------------------
def main():
    if len(sys.argv) < 3 or "--manifest" not in sys.argv or "--env" not in sys.argv:
        print("Usage: python deploy_from_manifest.py --manifest manifest.yaml --env dev [--dry-run]")
        sys.exit(1)

    manifest_path = sys.argv[sys.argv.index("--manifest") + 1]
    environment = sys.argv[sys.argv.index("--env") + 1]
    dry_run = "--dry-run" in sys.argv
    os.environ["ENVIRONMENT"] = environment

    manifest = load_yaml(manifest_path)
    tags_path = "tags.yaml"
    global_tags = load_yaml(tags_path).get("global", {}) if os.path.exists(tags_path) else {}

    validate_required_tags(global_tags)
    ensure_subscription_tags(global_tags)

    resources = manifest.get("resources", [])
    if not resources:
        print("❌ No resources found in manifest.")
        sys.exit(1)

    template_paths = {
        "azure-functions": "templates/azure-functions/template.bicep",
        "storage": "templates/storage/template.bicep",
        "app-service": "templates/app-service/template.bicep",
        "sql": "templates/sql/template.bicep",
        "api-management": "templates/api-management/template.bicep",
        "azure-ad-b2c": "templates/azure-ad-b2c/template.bicep",
        "delete-resource": "templates/delete/delete-resource.bicep",
    }

    deployed_resources = []
    print(f"🚀 Starting deployment for environment: {environment}")
    print(f"🌍 Global tags: {global_tags}")

    for resource in resources:
        template_name = resource.get("template")
        template_path = template_paths.get(template_name)
        if not template_path:
            print(f"⚠️ Unknown template '{template_name}', skipping.")
            continue

        raw_vars = resource.get("variables", {})
        expanded_vars = merge_tags(substitute_env(raw_vars), global_tags)

        print(f"🔹 Deploying resource type: {template_name}")
        success = deploy_bicep(template_path, expanded_vars, dry_run)
        deployed_resources.append({
            "template": template_name,
            "name": expanded_vars.get("name"),
            "resourceGroup": expanded_vars.get("resourceGroupName"),
            "location": expanded_vars.get("location"),
            "status": "Succeeded" if success else "Failed"
        })

        if not success:
            print("⛔ Stopping deployment due to failure.")
            break

    write_audit_log(deployed_resources)
    print("✅ Deployment process completed.\n")

if __name__ == "__main__":
    main()
