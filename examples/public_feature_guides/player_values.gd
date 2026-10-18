extends Node

# Existing configured SDK and authenticated player session required.
# Invoke run_reviewed_action explicitly after reviewing this example.
func run_reviewed_action() -> void:
    if not Horizon.auth.isSignedIn():
        return
    var user_id: String = Horizon.auth.getCurrentUser().userId
    var current: Dictionary = await Horizon.playerValues.getState(user_id)
    if not current.success:
        push_error(current.errorCode)
        return
    print(current.state.values)
    # Authoritative balances only; never add a copied historical reward locally.
    # Purchases and exact original retry use the official player_values_example.gd
    # and pending_purchase.gd. Persist the original user/offer/operationId before send.
    # Keep an uncertain or expired original; do not silently create another ID.
