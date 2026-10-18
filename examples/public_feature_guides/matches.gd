extends Node

# Explicit action after restoring the SAME existing player identity.
func read_my_matches() -> void:
    var user = Horizon.auth.getCurrentUser()
    if user == null:
        return
    var result = await Horizon.matches.getMatches(user.userId)
    if not result.success:
        push_warning(result.errorCode)
        return
    print("Ledger revision: ", result.data.revision)
    for row in result.data.recent:
        print(row.id, " ", row.status) # May still be active after this player's forfeit.
    # Respect result.data.pollAfterSeconds. No background poll.
# Full two-player, durable-original example in the verified SDK:
# addons/horizon_sdk/examples/features/matches_example.gd
# read_matches()/create_reviewed(options), read_match(id), perform_reviewed(kind, body).
# Each is an explicit player action. Original project+player intent survives host changes.
# SDK methods: joinMatch(userId,id,originalRevision), startMatch(userId,id,originalRevision,order),
# submitTurn(userId,id,originalRevision,PackedByteArray,finish),
# reportResult(userId,id,originalFinalRevision,PackedByteArray,sortedWinnerIds).
# Unknown create: recovery reads and explicit reconciliation, never a replacement create.
# Report agreement is ordinary consensus, not validated combat or an automatic reward.
