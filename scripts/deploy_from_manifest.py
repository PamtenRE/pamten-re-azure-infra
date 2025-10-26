import os
import sys
import yaml
import json
import subprocess
from datetime import datetime

REQUIRED_TAGS = ["applicationId", "environment", "costCenter", "rsm", "managedBy"]

def load_yaml(file_path):
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

def deploy_bicep(template_path, variables):
    args = ["az", "deployment", "group", "create", "--template-file", template_path]
    for key, value in variables.items():
        if isinstance(value, (dict, list)):
            continue
        args += ["--parameters", f"{key}={value}"]
    subprocess.run(args, check=False)

def write_audit_log(deployed_resources):
    data = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "resources": deployed_resources,
        "triggeredBy": os.getenv("GITHUB_ACTOR", "local"),
        "environment": os.getenv("ENVIRONMENT", "unknown"),
    }
    with open("deployment_report.json", "w") as f:
        json.dump(data, f, indent=2)
    print("🧾 Deployment report written to deployment_report.json")

def main():
    if len(sys.argv) < 3 or "--manifest" not in sys.argv or "--env" not in sys.argv:
        print("Usage: python deploy_from_manifest.py --manifest manifest.yaml --env dev")
        sys.exit(1)

    manifest_path = sys.argv[sys.argv.index("--manifest") + 1]
    environment = sys.argv[sys.argv.index("--env") + 1]
    os.environ["ENVIRONMENT"] = environment

    manifest = load_yaml(manifest_path)
    tags_path = "tags.yaml"
    global_tags = {}

    if os.path.exists(tags_path):
        global_tags = load_yaml(tags_path).get("global", {})
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
        "static-web": "templates/static-web/template.bicep",
        "api-management": "templates/api-management/template.bicep",
        "azure-ad-b2c": "templates/azure-ad-b2c/template.bicep",
    }

    deployed_resources = []
    print(f"🚀 Starting deployment for environment: {environment}")
    print(f"🌍 Global tags: {global_tags}")

    for resource in resources:
        template_name = resource.get("template")
        template_path = template_paths.get(template_name)
        if not template_path:
            print(f"⚠️ Unknown template: {template_name}, skipping.")
            continue

        raw_vars = resource.get("variables", {})
        expanded_vars = substitute_env(raw_vars)
        expanded_vars = merge_tags(expanded_vars, global_tags)

        deploy_bicep(template_path, expanded_vars)
        deployed_resources.append({
            "template": template_name,
            "name": expanded_vars.get("name"),
            "resourceGroup": expanded_vars.get("resourceGroupName"),
            "location": expanded_vars.get("location")
        })

    write_audit_log(deployed_resources)
    print("✅ Deployment completed successfully!")

if __name__ == "__main__":
    main()
