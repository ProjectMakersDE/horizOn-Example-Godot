#!/usr/bin/env python3
"""Verify the complete official SDK snapshot without network access or secrets."""
from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]
record=json.loads((root/'SDK-SOURCE.json').read_text())
assert record['repository']=='ProjectMakersDE/horizOn-SDK-Godot'
assert re.fullmatch('[0-9a-f]{40}',record['commit'])
files=record['files'];assert files
for name,proof in files.items():
 path=Path(name)
 assert path.parts[:2]==('addons','horizon_sdk')and'..'not in path.parts and not path.is_absolute(),name
 assert hashlib.sha256((root/path).read_bytes()).hexdigest()==proof['sha256'],name
extras={str(p.relative_to(root))for p in(root/'addons/horizon_sdk').rglob('*')if p.is_file()}-set(files)
assert all(n.endswith(('.gd.uid','.png.import'))or n=='addons/horizon_sdk/horizon_config.tres'for n in extras),extras
print(f"Official SDK snapshot verified: {record['commit']}, {len(files)} exact files; generated Godot companions are separate.")
