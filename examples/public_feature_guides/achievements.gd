extends Node

# Existing configured SDK and authenticated player session required.
# Invoke run_reviewed_action explicitly after reviewing this example.
# This explicit action unlocks the shown configured achievement key.
func run_reviewed_action() -> void:
    if not Horizon.auth.isSignedIn():
        return
    var user_id: String = Horizon.auth.getCurrentUser().userId
    var loaded: Dictionary = await Horizon.achievements.getAchievements(user_id, "")
    if not loaded.success:
        push_warning(loaded.errorCode)
        return
    for progress in loaded.data.progress:
        print(progress.key, ": ", progress.rewardState)

    # Configure manual first_steps; invoke on the corresponding game action.
    var unlocked: Dictionary = await Horizon.achievements.unlock(user_id, "first_steps")
    if not unlocked.success:
        push_warning(unlocked.errorCode) # After timeout retry the same key.
        return
    # Complete progress has no unlock date or pending reward payload.
    # Values were credited atomically. Refresh playerValues when displaying balances.
    # No Inbox claim or local value addition. Retry the original key after an uncertain reply.
