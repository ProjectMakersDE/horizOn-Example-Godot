#!/usr/bin/env python3
"""Compile the native Develop entry and test its file gates without any API action."""
import os
from pathlib import Path
import shutil
import sys
import run_checks as native


def main():
    native.QA = native.ROOT / "tmp" / "develop-entry-selftest"
    native.QA_DATA_NAME = "horizon-task1016-develop-selftest-" + native.QA_RUN_ID
    if native.QA.exists():
        shutil.rmtree(native.QA)
    shutil.copytree(native.ROOT, native.QA,
                    ignore=shutil.ignore_patterns('.git', '.godot', 'tmp', 'exports', 'horizon_config.tres'),
                    ignore_dangling_symlinks=True)
    project = native.QA / 'project.godot'
    project.write_text(project.read_text().replace('config/name="Seagull Storm"',
                       'config/name="Seagull Develop Entry Selftest"\nconfig/use_custom_user_dir=true\n'
                       f'config/custom_user_dir_name="{native.QA_DATA_NAME}"'))
    native.run('--headless', '--editor', '--import', '--quit')
    result = native.run('--headless', '--script', 'tests/develop_acceptance.gd', '--',
                        '--develop-acceptance-self-test')
    assert 'DEVELOP_ACCEPTANCE_FILE_GATES_PASS' in result
    print('Native Develop entry compiled; exact host, explicit approval and permanent command marker verified. No manifest or HTTP action executed.')


if __name__ == '__main__':
    try:
        main()
    finally:
        base = (Path.home() / 'Library/Application Support' if sys.platform == 'darwin'
                else Path(os.environ.get('APPDATA', '')) if sys.platform == 'win32'
                else Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))))
        owned = base / native.QA_DATA_NAME
        if owned.exists():
            shutil.rmtree(owned)
        if native.QA.exists():
            shutil.rmtree(native.QA)
