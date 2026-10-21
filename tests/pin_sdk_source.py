#!/usr/bin/env python3
"""Record an exact official addon, preserving the blank config outside runtime paths."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sdk-source', type=Path, required=True)
    parser.add_argument('--sdk-ref', default='HEAD')
    parser.add_argument('--tag')
    args = parser.parse_args()

    def git(*values):
        return subprocess.check_output(['git', '-C', str(args.sdk_source), *values])

    commit = git('rev-parse', args.sdk_ref + '^{commit}').decode().strip()
    if args.tag and git('rev-parse', args.tag + '^{commit}').decode().strip() != commit:
        raise SystemExit('Release tag does not identify the requested SDK revision')
    names = git('ls-tree', '-r', '--name-only', commit, 'addons/horizon_sdk').decode().splitlines()
    if not names:
        raise SystemExit('Official addon is empty')
    relocated = {'addons/horizon_sdk/horizon_config.tres': 'config/official-sdk/horizon_config.tres.example'}
    files = {}
    for name in names:
        official = git('show', commit + ':' + name)
        if (ROOT / name).read_bytes() != official:
            raise SystemExit('Embedded SDK differs from official source: ' + name)
        if name in relocated:
            if not re.search(rb'(?m)^api_key\s*=\s*""\s*$', official):
                raise SystemExit('Only a blank official config template can be pinned')
            target = ROOT / relocated[name]
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(official)
            (ROOT / name).unlink(missing_ok=True)
        files[name] = {'sha256': hashlib.sha256(official).hexdigest()}
    record = dict(repository='ProjectMakersDE/horizOn-SDK-Godot', commit=commit,
                  source='release tag ' + args.tag if args.tag else 'develop snapshot; no release',
                  configurationTemplates=relocated, files=files)
    if args.tag:
        record['tag'] = args.tag
    (ROOT / 'SDK-SOURCE.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'Pinned {len(files)} exact official addon files at {commit}')


if __name__ == '__main__':
    main()
