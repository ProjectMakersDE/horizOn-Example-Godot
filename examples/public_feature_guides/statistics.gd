extends Node

# Existing configured SDK and authenticated player session required.
# Invoke run_reviewed_action explicitly after reviewing this example.
# This explicit action reports the shown persisted batch.
func run_reviewed_action() -> void:
    if not Horizon.auth.isSignedIn():
        return
    var snapshot: Dictionary = await Horizon.statistics.getStatistics()
    if snapshot.is_empty():
        push_error(Horizon.statistics.getLastErrorCode())
        return
    var pending_path: String = "user://statistics_" + snapshot.userId + ".dat"
    var pending: Dictionary
    if FileAccess.file_exists(pending_path):
        var file := FileAccess.open(pending_path, FileAccess.READ)
        if file == null:
            return
        var saved: Variant = file.get_var()
        file.close()
        if not saved is Dictionary:
            return
        pending = saved
    else:
        pending = {"operationId": Horizon.statistics.createOperationId(),
            "updates": [{"key": "kills", "value": 3}, {"key": "best_score", "value": 250}]}
        var file := FileAccess.open(pending_path, FileAccess.WRITE)
        if file == null:
            return
        file.store_var(pending, false) # Variant storage preserves int64 values.
        file.flush()
        var saved_ok: bool = file.get_error() == OK
        file.close()
        if not saved_ok:
            return
    var original_bytes: PackedByteArray = FileAccess.get_file_as_bytes(pending_path)
    if original_bytes.is_empty():
        return
    var result: Dictionary = await Horizon.statistics.updateStatistics(pending.updates, pending.operationId)
    if result.is_empty():
        # Keep the file and original ID, including after timeout or OPERATION_EXPIRED.
        push_error(Horizon.statistics.getLastErrorCode())
        return
    # A delayed O1 success cannot remove another action's O2 original.
    if FileAccess.get_file_as_bytes(pending_path) == original_bytes:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(pending_path))
    print(result.values)
