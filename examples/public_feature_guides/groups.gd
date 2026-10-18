extends Node

# Restore the existing matching player and connect in the Quickstart first.
# Invoke explicitly from a player action, not from a poll or page loop.
func read_my_groups() -> void:
    var user = Horizon.auth.getCurrentUser()
    if user == null:
        return
    var result = await Horizon.groups.getGroups(user.userId)
    if not result.success:
        push_warning(result.errorCode)
        return
    print("Player revision: ", result.data.revision)
    for group in result.data.groups:
        print(group.id, " ", group.myRole, " revision=", group.revision)
    # result.data.limits contains all current limits; retained groups are not truncated.
    # getMembers(userId, groupId, "", 1) reads one page. Keep its revision/cursor.
    # Restart explicitly on a changed revision; optional createdAt is not epoch zero.
# Full durable mutations: addons/horizon_sdk/examples/features/groups_example.gd.
# Keep the original revision/requestId; unknown create requires explicit reconciliation.
