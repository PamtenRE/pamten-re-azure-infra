from pathlib import Path
import json
import os
import shutil
import sys

# Add parent scripts dir to path so we can import the module
REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / 'scripts'
sys.path.insert(0, str(SCRIPTS_DIR))

import deploy_from_manifest as dfm


def test_create_and_read():
    mapping = {'environment': 'test', 'foo': 'bar'}
    tmp_path = dfm._create_azure_param_json_file(mapping)
    assert Path(tmp_path).is_file(), f"Temp file {tmp_path} was not created"
    with open(tmp_path, 'r', encoding='utf-8') as f:
        obj = json.load(f)
    assert obj.get('parameters', {}).get('foo', {}).get('value') == 'bar'
    # cleanup
    Path(tmp_path).unlink()
    print('test_create_and_read: PASS')


def test_find_env_parameters_file():
    test_env = 'testparams'
    env_dir = dfm.ENVS_DIR / test_env
    try:
        env_dir.mkdir(parents=True, exist_ok=False)
    except FileExistsError:
        # ensure it's empty
        shutil.rmtree(env_dir)
        env_dir.mkdir()
    yaml_path = env_dir / 'parameters.yaml'
    content = 'environment: test\nfoo: baz\n'
    yaml_path.write_text(content, encoding='utf-8')
    temp_json = dfm.find_env_parameters_file(test_env)
    assert temp_json is not None
    assert Path(temp_json).is_file()
    with open(temp_json, 'r', encoding='utf-8') as f:
        obj = json.load(f)
    assert obj.get('parameters', {}).get('foo', {}).get('value') == 'baz'
    # cleanup
    Path(temp_json).unlink()
    shutil.rmtree(env_dir)
    print('test_find_env_parameters_file: PASS')


if __name__ == '__main__':
    test_create_and_read()
    test_find_env_parameters_file()
    print('ALL TESTS PASS')
