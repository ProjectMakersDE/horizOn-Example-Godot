extends Node

# Verified SDK Develop API. Call explicitly after restoring the existing player.
func read_world_map() -> void:
    var user = Horizon.auth.getCurrentUser()
    if user == null:
        return
    var result = await Horizon.sharedObjects.queryObjects(user.userId, "bases", {
        "mode": "rectangle", "minX": -10, "maxX": 10,
        "minY": -10, "maxY": 10, "limit": 20
    })
    if not result.success:
        push_warning(result.errorCode)
        return
    for object in result.data.objects:
        var bytes: PackedByteArray = object.data
        print(object.id, " bytes=", bytes.size())
    # Respect result.data.pollAfterSeconds; no automatic poll or page loop.
    # Keep dataBase64 and lossless search-string wrappers unchanged on metadata edits.
    # Mutations need durable original bytes, IDs and If-Match revision before one send.
    # An unknown create is reconciled through getRecoveryUsage/queryRecoveryObjects.
    # No new identity, replacement revision or automatic create retry.
