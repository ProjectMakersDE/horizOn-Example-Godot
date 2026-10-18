extends Node

# Existing configured SDK and authenticated player session required.
# Invoke run_reviewed_action explicitly after reviewing this example.
func run_reviewed_action() -> void:
    if not Horizon.auth.isSignedIn():
        return
    var user_id: String = Horizon.auth.getCurrentUser().userId
    var loaded: Dictionary = await Horizon.friends.getFriends(user_id)
    if not loaded.success:
        push_warning(loaded.errorCode)
        return
    print(loaded.data.friendCode) # Public identifier, not a credential.
    for friend in loaded.data.friends:
        print(friend.display.name, ": ", friend.lastActiveAt) # null means unknown, not offline.

    # Examples for explicit player actions, never run these as an automatic sequence:
    # var found = await Horizon.friends.findPlayer(user_id, exact_uuid_or_h_code)
    # var r = await Horizon.friends.sendRequest(user_id, target_id, reviewed_revision)
    # var r = await Horizon.friends.acceptRequest(user_id, target_id, reviewed_revision, original_request_id)
    # var r = await Horizon.friends.declineRequest(user_id, target_id, reviewed_revision, original_request_id)
    # var r = await Horizon.friends.cancelRequest(user_id, target_id, reviewed_revision, original_request_id)
    # var r = await Horizon.friends.removeFriend(user_id, target_id, reviewed_revision)
    # var r = await Horizon.friends.blockPlayer(user_id, target_id, reviewed_revision)
    # var r = await Horizon.friends.unblockPlayer(user_id, target_id, reviewed_revision)
    # Success: replace the entire snapshot with r.data. Do not patch one side locally.
    # Timeout/REVISION_CONFLICT: refresh and reconcile; never silently substitute a new revision.
    # Keep original incoming requestId for accept/decline, outgoing requestId for cancel.
    # Inbox notices are hints; only the current snapshot authorizes a request action.
    # Refresh explicitly on reconnect/metadata invalidation; no hidden polling timer.
