# Explicit native Develop acceptance

`tests/develop_acceptance.gd` is an opt-in native QA entry. Normal game/Hello startup and exported release behavior are unchanged. It is prepared tooling, not a completed deployed acceptance. Only `http://127.0.0.1:3170` is accepted; Root must first approve the deployed revisions and supply the owned PRO project and private app key.

Prepare an owned copy of the current source, excluding `.git`, `.godot`, `tmp`, `exports` and any personal `horizon_config.tres`. Before launching Godot, configure `application/config/use_custom_user_dir=true` and a unique `application/config/custom_user_dir_name` starting with `horizon-task1016-develop-`. Each participant has a separate profile. Run the real installed native Godot with `--path <owned-copy> --script tests/develop_acceptance.gd -- --develop-acceptance=/absolute/private/manifest.json`. No host or credential is passed as a CLI value.

The private manifest requires `stage: "develop"`, `rootApproved: true`, exact `baseUrl`, canonical UUID `runId` and `projectId`, `appApiKey`, exact lowercase 40-character `serverCommit` and `dashboardCommit`, an existing absolute `controlDirectory`, and `allowWrites`. Use owned mode0700 directories and umask077. Keep the manifest outside the command directory. Configuration and the normal SDK connection do not create a player or start a business action.

Atomically add complete commands named `<canonical-UUID>.json` to that directory, with matching `id` and a fixed `action`. Results under `results/<id>.json` are private: creation may return the original guest recovery credential. Never log, commit or publish those files. Report only sanitized identifiers, statuses, revisions, hashes and timings.

- `createGuest` requires `confirm: true` and calls the actual game authentication path once. `restoreSaved` restores the owned profile; a missing/failed identity never becomes a replacement guest.
- `restoreGuest` requires explicit confirmation and the original credential's exact UTF-8 bytes in `dataBase64`. It uses the native SDK to restore that same player, for cross-engine Cloud Save acceptance. It refuses an existing different local identity.
- `feature` invokes the actual Feature Lab `execute` boundary with `feature`, `operation`, and `argumentsJson: "{\"args\":[...]}"`. Require explicit confirmation and use the existing feature-specific originals. UI invocation alone is not successful business evidence.
- `loadJson` / `loadBinary` read the actual Cloud Save, exact Base64 bytes and canonical revision string. Unknown revision remains unknown.
- `saveJson` / `saveBinary` require explicit confirmation, original `expectedRevision` and exact `dataBase64`, then call the native conditional save once. A stale409 is reported without rebasing or automatic retry.
- `guide` invokes the complete copied `groups`, `items`, `matches` or `shared-objects` public guide Read method in the existing session. It reports first actual HTTP response timing separately from DTO/business validation; this is not a fresh-install timing claim.
- `capture` stores a private screenshot for later privacy review; `quit` closes the owned native process.

A permanent `.started` directory is claimed before dispatch. Restart cannot automatically repeat an uncertain command. Existing markers return `UNKNOWN_OUTCOME_ORIGINAL_RETAINED`; reconcile the unchanged SDK original and authoritative state explicitly. Partial result files are retained and stop processing. No new operation ID, revision or counter is invented to make a result pass.

TASK-1024 uses this native Godot client with the original Unity guest identity: both load R, Unity JSON→R+1, Godot original stale write409, reload exact JSON, Godot binary→R+2, Unity original stale write409, reload exact binary, explicit JSON→R+3. Confirm identical player IDs and exact payload hashes before reporting actual Develop success.

`GODOT_BIN=/path/to/godot python3 tests/run_develop_entry_checks.py` compiles the full native source and this entry, and checks exact host, approval and permanent command markers in isolated temporary userdata. It supplies no real manifest and executes no HTTP action. Existing source CI and synthetic transport evidence remain separate.
