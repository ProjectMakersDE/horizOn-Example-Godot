extends Node

const MarketStart = preload("res://addons/horizon_sdk/examples/features/marketplace_quickstart.gd")
# Attach marketplace_example.gd to this screen, set its stable project_id,
# and use the existing authenticated Horizon session for this project.
@export var screen: Node

func read_listing(listing_id: String) -> Dictionary:
    return await MarketStart.read_one_listing(screen, listing_id)

# Wire only to explicit Buy confirmation after displaying a successful read.
func confirm_purchase(listing_id: String) -> Dictionary:
    return await MarketStart.buy_reviewed_listing(screen, listing_id)

# Unknown outcome: await screen.retry_pending() or recover_original_operation().
# Keep the original until Inventory, Values and Marketplace have refreshed.
# Never delete a pending operation or unknown send-owner lock to buy again.