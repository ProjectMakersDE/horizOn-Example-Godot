extends Node

# Existing configured SDK and authenticated player session required.
# Invoke run_reviewed_action explicitly after reviewing this example.
func run_reviewed_action() -> void:
    if not Horizon.auth.isSignedIn():
        return
    var user_id: String = Horizon.auth.getCurrentUser().userId
    var loaded: Dictionary = await Horizon.inbox.getInbox(user_id, "")
    if not loaded.success:
        push_error(loaded.errorCode)
        return
    for entry in loaded.data.entries:
        print(entry.textKey)
    # The SDK materializes unchanged responses from its project/player cache.
    # Respect loaded.data.pollAfterSeconds and stop refreshing with the game lifecycle.

    var claim_state := {"busy": false}
    var claim_selected = func(entry_id: String) -> void:
        if claim_state.busy:
            return
        var project_id := "YOUR_PROJECT_ID"
        var path := "user://inbox_claim_" + project_id + "_" + user_id + ".txt"
        if FileAccess.file_exists(path):
            var previous := FileAccess.open(path, FileAccess.READ)
            if previous == null:
                return
            var pending := previous.get_as_text()
            previous.close()
            if pending != entry_id:
                return # Resolve the original claim first.
        else:
            var current: Dictionary = Horizon.inbox.getCurrentInbox()
            if current.get("userId", "") != user_id:
                return
            var selected: Dictionary = {}
            for entry in current.get("entries", []):
                if entry.id == entry_id:
                    selected = entry
                    break
            if selected.is_empty() or selected.claimed:
                return
            var attachment = selected.get("attachment")
            if not attachment is Dictionary or attachment.get("values", []).is_empty():
                return
        # An existing identical pending ID bypasses this new-selection guard for safe replay.
        var file := FileAccess.open(path, FileAccess.WRITE)
        if file == null:
            return
        file.store_string(entry_id)
        file.flush()
        var saved_ok := file.get_error() == OK
        file.close()
        if not saved_ok:
            return
        claim_state.busy = true
        var claimed: Dictionary = await Horizon.inbox.claim(user_id, entry_id)
        claim_state.busy = false
        if not claimed.success:
            push_error(claimed.errorCode)
            return
        # Display claimed.data.inbox and replace values with claimed.data.playerValues.
        # Never add the reward delta locally.
        var current := FileAccess.open(path, FileAccess.READ)
        if current != null:
            var still_pending := current.get_as_text() == entry_id
            current.close()
            if still_pending:
                DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    # Bind claim_selected to an explicit player action; do not claim automatically.
    # Retry the same saved entry_id after an uncertain response.
    # Other deliberate actions: await Horizon.inbox.markRead(user_id, entry_id)
    # await Horizon.inbox.remove(user_id, entry_id) # Protects unclaimed rewards.
