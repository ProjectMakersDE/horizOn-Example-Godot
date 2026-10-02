#!/usr/bin/env python3
"""Verify the macOS export with isolated fixtures, rendered UI and native physics."""
from __future__ import annotations
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN", "/Applications/Godot.app/Contents/MacOS/Godot")
ARTIFACTS = Path(os.environ.get("SEAGULL_QA_ARTIFACT_DIR", str(ROOT / "tmp/verification-artifacts")))
QA = ROOT / "tmp/qa-project"
NATIVE_QA = ROOT / "exports/isolated-native-qa"


def run(name: str, args: list[str]) -> str:
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, timeout=150)
    output = result.stdout + result.stderr
    (ROOT / "tmp" / name).write_text(output)
    print(name, "exit", result.returncode, flush=True)
    if result.returncode or "SCRIPT ERROR" in output or "ERROR:" in output:
        print(output[-6000:], flush=True)
        raise RuntimeError(f"Verification failed: {name}")
    return output


def main() -> None:
    if sys.platform != "darwin":
        raise SystemExit("This export verifier requires macOS and the Godot macOS export template.")
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    (ROOT / "tmp").mkdir(exist_ok=True)
    run("release-checks.log", [sys.executable, "tests/run_checks.py"])
    run("release-captures.log", [sys.executable, "tests/run_checks.py", "--render"])
    run("release-import.log", [GODOT, "--headless", "--editor", "--path", str(ROOT), "--import", "--quit"])
    run("release-export.log", [GODOT, "--headless", "--path", str(ROOT), "--export-release", "macOS", "exports/SeagullStorm.zip"])
    project = QA / "project.godot"
    project.write_text(project.read_text().replace("run/main_scene=", 'run/main_loop_type="SeagullOfflineSmoke"\nrun/main_scene='))
    script = QA / "tests/offline_smoke.gd"
    script.write_text(script.read_text().replace("extends SceneTree", "class_name SeagullOfflineSmoke\nextends SceneTree"))
    preset = QA / "export_presets.cfg"
    preset.write_text(preset.read_text().replace("tests/*,", ""))
    run("release-isolated-import.log", [GODOT, "--headless", "--editor", "--path", str(QA), "--import", "--quit"])
    pack = ROOT / "tmp/isolated-native-qa.pck"
    run("release-isolated-pack.log", [GODOT, "--headless", "--path", str(QA), "--export-pack", "macOS", str(pack)])
    NATIVE_QA.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(ROOT / "exports/SeagullStorm.zip") as archive:
        archive.extractall(NATIVE_QA)
    app = NATIVE_QA / "Seagull Storm.app"
    packs = list((app / "Contents/Resources").glob("*.pck"))
    assert len(packs) == 1, "Export must contain exactly one game pack"
    # Release templates disable --main-pack overrides. Substitute a QA-only
    # embedded pack in this owned app copy; the deliverable ZIP is untouched.
    shutil.copy2(pack, packs[0])
    player = app / "Contents/MacOS/Seagull Storm"
    player.chmod(0o755)
    output = run("release-native-smoke.log", [str(player), "--headless"])
    assert "OFFLINE_SMOKE_PASS" in output
    for pattern in ["qa-*.png", "release-*.log", "check-*.log"]:
        for path in (ROOT / "tmp").glob(pattern):
            shutil.copy2(path, ARTIFACTS / path.name)
    shutil.copy2(ROOT / "exports/SeagullStorm.zip", ARTIFACTS / "SeagullStorm.zip")
    shutil.copy2(pack, ARTIFACTS / pack.name)
    print("RELEASE_VERIFY_PASS: current code, SDK fixture, UI captures, universal export binary gameplay; artifacts", ARTIFACTS, flush=True)


def cleanup() -> None:
    project = QA / "project.godot"
    if project.exists():
        match = re.search(r'config/custom_user_dir_name="(horizon-task913-godot-qa-[0-9a-f]{12})"', project.read_text())
        if match:
            userdata = Path.home() / "Library/Application Support" / match.group(1)
            if userdata.exists():
                shutil.rmtree(userdata)
        shutil.rmtree(QA)
    if NATIVE_QA.exists():
        shutil.rmtree(NATIVE_QA)


if __name__ == "__main__":
    try:
        main()
    finally:
        cleanup()
