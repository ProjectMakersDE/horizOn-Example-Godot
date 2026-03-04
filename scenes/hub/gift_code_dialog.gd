## Gift Code Dialog - Validate and redeem gift codes
extends PanelContainer

@onready var code_input: LineEdit = $VBox/CodeInput
@onready var validate_button: Button = $VBox/ValidateButton
@onready var redeem_button: Button = $VBox/RedeemButton
@onready var close_button: Button = $VBox/CloseButton
@onready var status_label: Label = $VBox/StatusLabel


func _ready() -> void:
	validate_button.pressed.connect(_on_validate)
	redeem_button.pressed.connect(_on_redeem)
	close_button.pressed.connect(func(): visible = false)
	redeem_button.disabled = true
	status_label.text = ""


func _on_validate() -> void:
	var code := code_input.text.strip_edges()
	if code.is_empty():
		status_label.text = "Enter a code."
		return

	status_label.text = "Validating..."
	var result = await Horizon.giftCodes.validate(code)
	if result == true:
		status_label.text = "Code is valid!"
		redeem_button.disabled = false
	elif result == false:
		status_label.text = "Invalid code."
		redeem_button.disabled = true
	else:
		status_label.text = "Validation error."
		redeem_button.disabled = true


func _on_redeem() -> void:
	var code := code_input.text.strip_edges()
	if code.is_empty():
		return

	# Check if already redeemed locally
	if code in GameManager.save_data.giftCodesRedeemed:
		status_label.text = "Already redeemed!"
		return

	status_label.text = "Redeeming..."
	var result := await Horizon.giftCodes.redeem(code)
	if result.get("success", false):
		var gift_data: String = result.get("giftData", "")
		var parsed = JSON.parse_string(gift_data)
		if parsed is Dictionary and parsed.has("coins"):
			GameManager.save_data.coins += int(parsed["coins"])
			GameManager.coins_changed.emit(GameManager.save_data.coins)
		GameManager.save_data.giftCodesRedeemed.append(code)
		status_label.text = "Code redeemed!"
		redeem_button.disabled = true
		Horizon.crashes.record_breadcrumb("user_action", "redeemed_gift_code_%s" % code)
	else:
		status_label.text = result.get("message", "Redemption failed.")
