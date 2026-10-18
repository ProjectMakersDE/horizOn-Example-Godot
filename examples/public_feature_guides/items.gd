extends Node

# Connect and restore the existing player first. Each function is an explicit action.
func read_inventory() -> void:
    var user = Horizon.auth.getCurrentUser()
    if user == null:
        return
    var result = await Horizon.items.getInventory(user.userId)
    if not result.success:
        push_warning(result.errorCode)
        return
    for item in result.data.instances:
        print(item.instanceId, ": ", item.itemKey)
    # Keep result.data.revision for a separately reviewed mutation.

func read_catalog_page() -> void:
    var user = Horizon.auth.getCurrentUser()
    if user == null:
        return
    var result = await Horizon.items.getCatalog(user.userId, "", 1)
    if not result.success:
        push_warning(result.errorCode)
        return
    print("Catalog revision: ", result.data.revision)
    # Explicit Next retains revision and nextAfterKey; no automatic page loop.
# Durable mutations: addons/horizon_sdk/examples/features/items_example.gd.
# Preserve original instance/body/revision and the original PV purchase operationId.
# Initial success may include item references; retained replay may return empty applied/items.
# Read the current inventory separately; never reconstruct earlier item references.
# A failed refresh never authorizes another purchase or a local item grant.
