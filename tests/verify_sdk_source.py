#!/usr/bin/env python3
"""Verify exact official source, relocated blank config and fresh-checkout completeness."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--sdk-source',type=Path)
args=parser.parse_args()
record=json.loads((root/'SDK-SOURCE.json').read_text())
assert record['repository']=='ProjectMakersDE/horizOn-SDK-Godot'
assert re.fullmatch('[0-9a-f]{40}',record['commit'])
files=record['files'];assert files
relocated=record.get('configurationTemplates',{})
assert relocated=={'addons/horizon_sdk/horizon_config.tres':'config/official-sdk/horizon_config.tres.example'}
for name,proof in files.items():
 path=Path(name)
 assert path.parts[:2]==('addons','horizon_sdk')and'..'not in path.parts and not path.is_absolute(),name
 actual=root/relocated.get(name,name)
 assert hashlib.sha256(actual.read_bytes()).hexdigest()==proof['sha256'],name
 if args.sdk_source:
  official=subprocess.check_output(['git','-C',str(args.sdk_source),'show',record['commit']+':'+name])
  assert actual.read_bytes()==official,'Official SDK differs: '+name
if args.sdk_source:
 official_names=set(subprocess.check_output(['git','-C',str(args.sdk_source),'ls-tree','-r','--name-only',record['commit'],'addons/horizon_sdk'],text=True).splitlines())
 assert set(files)==official_names,'Provenance must include the complete official addon'
 if record.get('tag'):
  tag_commit=subprocess.check_output(['git','-C',str(args.sdk_source),'rev-parse',record['tag']+'^{commit}'],text=True).strip()
  assert tag_commit==record['commit'],'Release tag must identify the pinned revision'
assert re.search(r'(?m)^api_key\s*=\s*""\s*$',(root/next(iter(relocated.values()))).read_text()),'Only the blank official config template belongs in source'
extras={str(p.relative_to(root))for p in(root/'addons/horizon_sdk').rglob('*')if p.is_file()}-set(files)
assert all(n.endswith(('.gd.uid','.png.import'))or n=='addons/horizon_sdk/horizon_config.tres'for n in extras),extras
if(root/'.git').exists():
 tracked=set(subprocess.check_output(['git','ls-files'],cwd=root,text=True).splitlines())
 assert {relocated.get(name,name)for name in files}.issubset(tracked),'Official source files are locally ignored instead of tracked'
 assert 'addons/horizon_sdk/horizon_config.tres'not in tracked,'Imported personal runtime config must stay ignored'
print(f"Official SDK {record['commit']}: {len(files)} exact files, one relocated blank config template; personal runtime config stays ignored")
guides=root/'examples/public_feature_guides';guide_proof=json.loads((guides/'SOURCE.json').read_text())
# Public snippets retain the SDK revision against which they were authored.
# The native feature-lab gate checks compatibility with the current addon.
assert re.fullmatch('[0-9a-f]{40}',guide_proof['sdk'])
for name,proof in guide_proof['files'].items():assert hashlib.sha256((guides/name).read_bytes()).hexdigest()==proof['sha256'],name
