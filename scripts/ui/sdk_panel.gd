extends VBoxContainer

var status: Label
var output: Label
var _busy := false

func _ready() -> void:
	StormUI.label(self, "Your backend, in the game", 23)
	StormUI.label(self, "Optional SDK operations. Each action below uses the signed-in player. Offline practice makes no backend calls.", 15, StormUI.MUTED)
	status = StormUI.label(self, "SDK %s · %s" % [Horizon.getVersion(), "offline" if GameManager.practice_mode else "online"], 15, StormUI.TEAL)
	var row := HBoxContainer.new()
	add_child(row)
	StormUI.button(row, "News", _news)
	StormUI.button(row, "Player profile", _profile)
	StormUI.button(row, "Validated state", _state)
	var row2 := HBoxContainer.new()
	add_child(row2)
	StormUI.button(row2, "Gift code", _gift)
	StormUI.button(row2, "Feedback", _feedback)
	StormUI.button(row2, "Sync save", _save)
	var row3 := HBoxContainer.new()
	add_child(row3)
	StormUI.button(row3, "Localization", _localization)
	StormUI.button(row3, "Diagnostics", _diagnostics)
	StormUI.button(row3, "Email Sending", _email_status)
	StormUI.button(self, "Player Values", _player_values)
	StormUI.button(self, "Statistics", _statistics)
	output = StormUI.label(self, "Run summaries use User Logs. Crash Reporting records navigation, waves and upgrades. Remote Config tunes gameplay. Profile, validated values and evidence use SDK 1.8.0.", 16)
	if GameManager.practice_mode:
		for row_node in [row, row2, row3]:
			for child in row_node.get_children():
				child.disabled = true

func _begin(action: String) -> bool:
	if _busy or not GameManager.online_available():
		return false
	_busy = true
	status.text = action + "…"
	return true

func _done(message: String) -> void:
	if not is_instance_valid(status):
		return
	_busy = false
	status.text = message

func _news() -> void:
	if not _begin("Loading news"):
		return
	var entries: Array = await Horizon.news.loadNews(5, "en")
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var lines: Array[String] = []
	for item in entries:
		lines.append(item.title + "\n" + item.message)
	output.text = "\n\n".join(lines) if not lines.is_empty() else "No news returned. Publish news for this API key in your dashboard."
	_done("News request completed; an empty list can also mean unavailable.")

func _profile() -> void:
	if not _begin("Loading player profile"):
		return
	var result: Dictionary = await Horizon.playerProfile.getProfile()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	output.text = "Player: %s · best %d · runs %d\n" % [Horizon.getCurrentUser().displayName, GameManager.save_data.highscore, GameManager.save_data.totalRuns] + JSON.stringify(result.get("profile", {}), "  ") + "\nAvailable cosmetics: " + str(result.get("cosmetics", []).size())
	_done("Profile loaded" if not result.is_empty() else "Profile unavailable: " + Horizon.playerProfile.getLastErrorCode())
	if result.is_empty():
		return
	var dialog := _dialog("Equip an available avatar")
	var picker := OptionButton.new()
	picker.add_item("Keep current avatar")
	var ids: Array[String] = [str(result.get("profile", {}).get("avatarId", ""))]
	for cosmetic in Horizon.playerProfile.getCosmetics("avatar"):
		if cosmetic.get("available", false):
			ids.append(str(cosmetic.get("id", "")))
			picker.add_item(ids[-1])
	dialog.add_child(picker)
	var info := StormUI.label(dialog, "Only server-available cosmetics can be equipped. Frame and badges are preserved.", 15, StormUI.MUTED)
	StormUI.button(dialog, "Apply avatar", func():
		var current: Dictionary = result.get("profile", {})
		var changed: Dictionary = await Horizon.playerProfile.setProfile(ids[picker.selected], str(current.get("frameId", "")), current.get("badges", []))
		if not is_instance_valid(info):
			return
		info.text = "Profile saved." if not changed.is_empty() else "Profile refused: " + Horizon.playerProfile.getLastErrorCode()
	)

func _state() -> void:
	if not _begin("Loading server-owned values"):
		return
	var result: Dictionary = await Horizon.validatedActions.getState()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	var lines: Array[String] = ["Server day: " + str(result.get("day", ""))]
	for value in result.get("values", []):
		lines.append("%s: %d · earned today %d · cap %d" % [value.get("key", ""), value.get("balance", 0), value.get("earnedToday", 0), value.get("dailyCap", 0)])
	output.text = "\n".join(lines) + "\nThese balances are separate from the example's cloud/local upgrade coins."
	_done("State loaded" if not result.is_empty() else "Validated state unavailable: " + Horizon.validatedActions.getLastErrorCode())

func _save() -> void:
	if not _begin("Saving player progress"):
		return
	await GameManager.save_data_to_cloud()
	_done(GameManager.cloud_status)

func _gift() -> void:
	var dialog := _dialog("Redeem a gift code")
	var field := StormUI.input(dialog, "Gift code")
	var info := StormUI.label(dialog, "Validate first, then redeem. Cosmetic unlocks appear in your player profile.", 15, StormUI.MUTED)
	var validated_code := [""]
	var redeem := StormUI.button(dialog, "Redeem", func():
		if field.text.strip_edges() != validated_code[0] or validated_code[0].is_empty():
			return
		if not GameManager.can_mutate_progress():
			info.text = "Wait for the initial cloud save load before redeeming rewards."
			return
		var generation := GameManager.state_generation()
		var owner := GameManager.state_owner()
		info.text = "Redeeming…"
		var requested_code: String = validated_code[0]
		validated_code[0] = ""
		var result: Dictionary = await Horizon.giftCodes.redeem(requested_code)
		if generation != GameManager.state_generation() or owner != GameManager.state_owner():
			return
		if result.get("success", false):
			if is_instance_valid(info):
				info.text = "Gift redeemed. Unlocks: " + str(result.get("grantedUnlocks", []))
			var reward: Variant = JSON.parse_string(str(result.get("giftData", "")))
			if reward is Dictionary:
				GameManager.save_data.coins += maxi(int(reward.get("coins", 0)), 0)
				GameManager.coins_changed.emit(GameManager.save_data.coins)
				await GameManager.save_data_to_cloud()
		elif is_instance_valid(info):
			info.text = "Redemption refused: " + str(result.get("message", "unavailable"))
		validated_code[0] = ""
	)
	redeem.disabled = true
	field.text_changed.connect(func(_text): redeem.disabled = true)
	StormUI.button(dialog, "Validate code", func():
		var requested_code := field.text.strip_edges()
		var value: Variant = await Horizon.giftCodes.validate(requested_code)
		if not is_instance_valid(info) or not is_instance_valid(field):
			return
		validated_code[0] = requested_code if value == true and field.text.strip_edges() == requested_code else ""
		redeem.disabled = validated_code[0].is_empty()
		info.text = "Code valid — ready to redeem." if value == true else "Code invalid or validation unavailable."
	)

func _feedback() -> void:
	var dialog := _dialog("Send feedback to your project")
	var title := StormUI.input(dialog, "Title")
	title.max_length = 100
	var message := TextEdit.new()
	message.placeholder_text = "Describe the bug or idea…"
	message.custom_minimum_size.y = 100
	dialog.add_child(message)
	var category := OptionButton.new()
	for value in ["GENERAL", "BUG", "FEATURE"]:
		category.add_item(value)
	dialog.add_child(category)
	var info := StormUI.label(dialog, "Your message is submitted only when you press Send.", 15, StormUI.MUTED)
	StormUI.button(dialog, "Send feedback", func():
		if title.text.strip_edges().is_empty() or message.text.strip_edges().is_empty() or message.text.length() > 2048:
			info.text = "Enter a title and a message of 1–2048 characters."
			return
		info.text = "Sending…"
		var ok := await Horizon.feedback.submit(title.text.strip_edges(), message.text, category.get_item_text(category.selected), "", false)
		if not is_instance_valid(info):
			return
		info.text = "Feedback sent." if ok else "Feedback failed. Retry when connected."
	)

func _localization() -> void:
	var dialog := _dialog("Switch the example UI language")
	var picker := OptionButton.new()
	picker.add_item("English", 0)
	picker.add_item("Deutsch", 1)
	picker.select(1 if GameManager.language == "de" else 0)
	dialog.add_child(picker)
	var info := StormUI.label(dialog, "Loads SDK localization keys seagull.play / seagull.upgrades. Built-in EN/DE labels cover missing keys.", 16, StormUI.MUTED)
	StormUI.button(dialog, "Apply language", func():
		var language := "de" if picker.selected == 1 else "en"
		Horizon.localization.setLanguage(language)
		var words: Dictionary = await Horizon.localization.getAllLocalizations(language)
		GameManager.language = language
		GameManager.translations = words
		GameManager.locale_changed.emit()
		if is_instance_valid(info):
			info.text = "UI language changed. Loaded %d localization keys." % words.size()
	)

func _diagnostics() -> void:
	if not _begin("Sending example diagnostic log"):
		return
	var result: Dictionary = await Horizon.userLogs.info("Seagull Storm SDK lab diagnostic button")
	var ok := not result.is_empty()
	if not is_instance_valid(self) or not is_inside_tree():
		return
	Horizon.crashes.record_breadcrumb("sdk_lab", "diagnostics_clicked")
	Horizon.crashes.set_custom_key("example", "Seagull Storm Godot")
	output.text = "User Logs summary sent: %s\nCrash breadcrumbs and custom keys prepared. No forced crash or exception is generated." % str(ok)
	_done("Diagnostic log sent" if ok else "Diagnostic log unavailable")

func _email_status() -> void:
	var dialog := _dialog("Email Sending / signed-in account")
	StormUI.label(dialog, "Use a template from your own dashboard. Pressing Queue sends to the signed-in player's account. No email is sent automatically.", 15, StormUI.MUTED)
	var template := StormUI.input(dialog, "Template slug (configured in dashboard)")
	var info := StormUI.label(dialog, "", 15)
	var queue := StormUI.button(dialog, "Queue email to my account", func(): pass)
	queue.disabled = Horizon.getCurrentUser().email.is_empty()
	if queue.disabled:
		info.text = "Use an email account to queue email; guest accounts have no recipient."
	queue.pressed.connect(func():
		if template.text.strip_edges().is_empty():
			info.text = "Enter a configured template slug."
			return
		queue.disabled = true
		var response: Dictionary = await Horizon.email_sending.send_email(Horizon.getCurrentUser().userId, template.text.strip_edges(), {"game": "Seagull Storm"}, GameManager.language)
		if is_instance_valid(info):
			info.text = "Queued: " + str(response.get("id", "unavailable")) if not response.is_empty() else "Queue failed. Check account email and template configuration."
		if is_instance_valid(queue):
			queue.disabled = false
	)
	var field := StormUI.input(dialog, "Existing email ID")
	StormUI.button(dialog, "Fetch email status", func():
		if field.text.strip_edges().is_empty():
			info.text = "Enter an existing email ID."
			return
		var response: Dictionary = await Horizon.email_sending.get_email_status(field.text.strip_edges())
		if is_instance_valid(info):
			info.text = "Status: " + str(response.get("status", "unavailable"))
	)

func _dialog(title: String) -> VBoxContainer:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.theme = StormUI.theme()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var scene := get_tree().current_scene
	if scene is Node2D and scene.has_node("CanvasLayer"):
		scene.get_node("CanvasLayer").add_child(layer)
	else:
		scene.add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -290
	panel.offset_right = 290
	panel.offset_top = -225
	panel.offset_bottom = 225
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	StormUI.label(column, title, 23)
	StormUI.button(column, "Close", func(): layer.queue_free())
	return column

func _player_values() -> void:
	var dialog := _dialog("Player Values")
	dialog.add_child(preload("res://scripts/ui/player_values_demo.gd").new())

func _statistics() -> void:
	var dialog := _dialog("Session statistics")
	dialog.add_child(preload("res://scripts/ui/statistics_demo.gd").new())
