extends Node

# Explicit read after restoring the SAME existing signed-in player.
func read_chat_snapshot(channel_id: String) -> void:
    var user = Horizon.auth.getCurrentUser()
    if user == null:
        return
    var result = await Horizon.chat.requestChannelSnapshot(user.userId, channel_id, "", [])
    if not result.success:
        push_warning(result.errorCode)
        return
    print("Snapshot epoch: ", result.data.channel.epoch)
    # This raw result never authorizes, opens or populates a managed feed.
    # watchChannel(user.userId, channel_id) waits for a confirmed subscription.
    # getCached(channel_id) is visible only while that watch is authorized.
    # No timer polling, disconnected HTTP fallback or automatic send/retry.
# Executable durable send/report UI: addons/horizon_sdk/examples/features/chat_example.gd.
# Persist the original project+player intent before sendMessage; host is only a request fence.
# Keep operationId, issuedAt, text and original report IDs/reason unchanged after timeout.
# getOperation 404 is not a confirmed failure. PHP returns 501 NOT_SUPPORTED.
