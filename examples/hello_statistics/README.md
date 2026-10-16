# Hello / Statistics

Open `hello_statistics.tscn` in Godot4.7 and run the current scene (F6). Import your
SDK configuration first. No authentication, read or write starts automatically.

1. Configure `rounds=sum`, `kills=sum`, `best_score=max`, all with reset `none`.
2. Connect/restore the guest. A failed restoration never creates a replacement identity.
3. Complete a sample round locally.
4. Read the snapshot and report the queued round explicitly.
5. After an uncertain response choose Retry original, retaining its ID/payload.

The Hello queue is isolated from the game by project, player and namespace. Binary
Variant storage preserves safe int64. Damaged/interrupted/expired state remains
blocked for reconciliation. Native smoke/render checks run through
`python3 tests/run_checks.py` and `python3 tests/run_checks.py --render` at repo root.
