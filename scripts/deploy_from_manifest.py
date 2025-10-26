#!/usr/bin/env python3
"""
deploy_from_manifest.py

This script reads a YAML manifest describing Azure resources and
deploys them using the Azure CLI.  It expects that you have already
logged into Azure via `azure/login@v2` in the calling GitHub
workflow.  Each environment (dev or prod) is a top-level key in the
manifest.  Under that key, a list of resources contains the
template identifier and variables mapping directly to Bicep
template parameters.  Tags are supported via a `tags` dictionary.

Usage:
    python deploy_from_manifest.py --manifest manifests/manifest.yml --env dev

Environment variables can be referenced in the manifest using the
syntax `${VAR_NAME}`.  The script will substitute those placeholders
with the value of the corresponding environment variable.  This is
useful for sensitive values such as administrator credentials.
"""

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional

try:
    import yaml  # PyYAML is required; install via pip if missing
except ImportError:
    print("PyYAML is not installed. Please install it with 'pip install pyyaml'.", file=sys.stderr)
    sys.exit(1)

# Location of the tags file.  It is resolved relative to this script's parent
# directory so it works from any working directory.
TAGS_FILE = Path(__file__).resolve().parent.parent / 'tags.yaml'
ENVS_DIR = Path(__file__).resolve().parent.parent / 'envs'

def load_tags(env_name: str) -> dict:
    """Load tags for the given environment from tags.yaml.

    If the file or the environment is not found, returns an empty dict.  The
    expected structure of tags.yaml is a top‑level mapping of environment
    names to dictionaries of tag key/value pairs.  For example:

        dev:
          Environment: dev
          Project: job-portal
          Owner: platform-team

        prod:
          Environment: prod
          Project: job-portal
          Owner: platform-team
    """
    try:
        if not TAGS_FILE.is_file():
            return {}
        with open(TAGS_FILE, 'r', encoding='utf-8') as f:
            tags_map = yaml.safe_load(f) or {}
        env_tags = tags_map.get(env_name) or {}
        # Ensure keys and values are strings
        return {str(k): str(v) for k, v in env_tags.items()}
    except Exception as exc:
        print(f"Warning: failed to load tags from {TAGS_FILE}: {exc}", file=sys.stderr)
        return {}

TEMPLATE_PATHS = {
    'azure-functions': 'templates/azure-functions/template.bicep',
    'storage': 'templates/storage/template.bicep',
    'app-service': 'templates/app-service/template.bicep',
    'sql': 'templates/sql/template.bicep',
}


def load_manifest(manifest_path: str) -> dict:
    """Load and parse the YAML manifest file."""
    with open(manifest_path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


def _create_azure_param_json_file(mapping: dict) -> str:
    """Create a temporary Azure parameters JSON file from a simple mapping.

    The YAML parameter files in `envs/` are expected to be a simple mapping of
    parameterName: value. This helper converts that into the Azure parameter
    file shape and writes it to a temp file. Returns the temp file path.
    """
    params_obj = {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
        "contentVersion": "1.0.0.0",
        "parameters": {k: {"value": v} for k, v in (mapping or {}).items()},
    }
    tf = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8')
    json.dump(params_obj, tf, indent=2)
    tf.close()
    return tf.name


def find_env_parameters_file(env_name: str) -> Optional[str]:
    """Look for a parameters file for the environment.

    Supports YAML files named `parameters.<env>.yaml` or `.yml` under
    `envs/<env>/`. If found, returns the path to a temporary JSON file
    converted to the Azure parameter format. The caller is responsible for
    cleaning up the returned file path (deleting it) after use.
    """
    env_dir = ENVS_DIR / env_name
    if not env_dir.is_dir():
        return None
    # Prefer a file named `parameters.yaml` inside the env dir, but also
    # support legacy `parameters.<env>.yaml` names.
    candidates = [env_dir / 'parameters.yaml', env_dir / 'parameters.yml', env_dir / f'parameters.{env_name}.yaml', env_dir / f'parameters.{env_name}.yml']
    for path in candidates:
        if path.is_file():
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    mapping = yaml.safe_load(f) or {}
                return _create_azure_param_json_file(mapping)
            except Exception as exc:
                print(f"Warning: failed to load environment parameters from {path}: {exc}", file=sys.stderr)
                return None
    return None


def substitute_env(value: str) -> str:
    """Replace ${VAR} with the environment variable value if present."""
    if isinstance(value, str) and value.startswith("${") and value.endswith("}"):
        env_name = value[2:-1]
        env_val = os.environ.get(env_name)
        if env_val is None:
            raise RuntimeError(f"Environment variable '{env_name}' is not set")
        return env_val
    return value


def build_az_command(resource_group: str, template_file: str, parameters: list, param_files: list = None) -> list:
    """Construct the az CLI command for deployment.

    `param_files` is an optional list of file paths that will be passed as
    `--parameters @file` to the az CLI. These files are added before the
    inline `key=value` parameters so inline parameters override file values.
    """
    cmd = [
        'az', 'deployment', 'group', 'create',
        '--resource-group', resource_group,
        '--template-file', template_file,
    ]
    # param_files should be specified as '@<path>' when passed to az
    for pf in (param_files or []):
        cmd.extend(['--parameters', f"@{pf}"])
    for param in parameters:
        cmd.extend(['--parameters', param])
    return cmd


def deploy_resources(env_name: str, manifest: dict, branch_name: Optional[str] = None) -> None:
    """Deploy resources for the specified environment."""
    if env_name not in manifest:
        raise RuntimeError(f"Environment '{env_name}' not found in manifest")
    env_data = manifest[env_name]
    resources = env_data.get('resources', [])
    # Load environment-level tags from tags.yaml.  These tags apply to every
    # resource unless overridden at the resource level.
    env_tags = load_tags(env_name)
    # If an env-level parameters YAML exists under envs/<env>/, convert it to
    # an Azure parameters JSON temp file and pass it to az. This allows teams
    # to keep parameters in YAML while the az CLI still receives JSON.
    # If a branch was supplied (from CI), prefer a branch-specific
    # parameters file under `envs/<branch_short>/parameters.yaml` first.
    env_param_file = None
    if branch_name:
        branch_short = str(branch_name).split('/')[-1]
        env_param_file = find_env_parameters_file(branch_short)
    if not env_param_file:
        env_param_file = find_env_parameters_file(env_name)
    for resource in resources:
        template_key = resource.get('template')
        if template_key not in TEMPLATE_PATHS:
            print(f"Warning: unknown template '{template_key}', skipping.")
            continue
        template_file = TEMPLATE_PATHS[template_key]
        variables = resource.get('variables', {})
        resource_group = variables.get('resourceGroupName')
        if not resource_group:
            print(f"Warning: resourceGroupName not specified for resource {variables.get('name', template_key)}, skipping.")
            continue
        params = []
        # Start with a copy of the environment tags
        combined_tags = dict(env_tags)
        for key, val in variables.items():
            # Skip resourceGroupName, handled separately
            if key == 'resourceGroupName':
                continue
            if key == 'tags' and isinstance(val, dict):
                # Merge resource-specific tags, overriding env-level ones
                for t_key, t_val in val.items():
                    combined_tags[str(t_key)] = str(t_val)
                continue  # Do not add 'tags' as a separate parameter here
            # Substitute environment variable placeholders
            try:
                substituted = substitute_env(val)
            except RuntimeError as e:
                print(f"Error: {e}", file=sys.stderr)
                sys.exit(1)
            params.append(f"{key}={substituted}")
        # Always append the combined tags
        if combined_tags:
            tags_json = json.dumps(combined_tags)
            params.append(f"tags={tags_json}")
        # Pass env-level param file first (if any), then inline params so inline
        # values override the file values.
        param_files = [env_param_file] if env_param_file else []
        cmd = build_az_command(resource_group, template_file, params, param_files=param_files)
        print('Executing:', ' '.join(cmd))
        result = subprocess.run(cmd, capture_output=True, text=True)
        print(result.stdout)
        if result.returncode != 0:
            print(result.stderr, file=sys.stderr)
            # Clean up any temporary env param file before exiting
            if env_param_file and Path(env_param_file).is_file():
                try:
                    Path(env_param_file).unlink()
                except Exception:
                    pass
            sys.exit(result.returncode)
        # Clean up the temp file after a successful run as well
        if env_param_file and Path(env_param_file).is_file():
            try:
                Path(env_param_file).unlink()
            except Exception:
                pass


def main() -> None:
    parser = argparse.ArgumentParser(description='Deploy Azure resources from a YAML manifest.')
    parser.add_argument('--manifest', required=True, help='Path to the manifest YAML file.')
    parser.add_argument('--env', required=True, help='Environment name (e.g. dev or prod).')
    parser.add_argument('--branch', required=False, help='Optional branch ref (e.g. refs/heads/develop or develop). If provided the script will prefer envs/<branch_short>/parameters.yaml')
    args = parser.parse_args()
    manifest_path = args.manifest
    env_name = args.env
    branch = args.branch
    if not Path(manifest_path).is_file():
        print(f"Manifest file not found: {manifest_path}", file=sys.stderr)
        sys.exit(1)
    manifest = load_manifest(manifest_path)
    try:
        deploy_resources(env_name, manifest, branch_name=branch)
    except RuntimeError as err:
        print(f"Error: {err}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()