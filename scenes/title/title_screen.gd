extends Control

var name_input: LineEdit
var email_input: LineEdit
var password_input: LineEdit
var status_label: Label
var online_button: Button
var auth_panel: VBoxContainer
var _busy := false
var _request_generation := 0

func _ready() -> void:
	AudioManager.play_music("music_menu")
	var page := StormUI.page(self, "Seagull Storm", "A small island. An enormous storm. Survive, collect shells, make your own build.")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(row)
	var hero := StormUI.scroll_card(row, 430)
	StormUI.label(hero, "DEFEND YOUR PATCH\nOF PARADISE.", 27, StormUI.ORANGE)
	StormUI.button(hero, "Play offline practice", _on_practice, true)
	StormUI.art(hero, "res://assets/shared/seagull_hero.png", 100)
	StormUI.label(hero, "Auto-attack survival • 3 minute runs • 4 weapons\nWASD / arrows to move · Space to dash · Esc to pause", 15)
	StormUI.label(hero, "Progress saves on this device. Practice scores stay local.", 13, StormUI.MUTED)
	auth_panel = StormUI.scroll_card(row, 420)
	StormUI.label(auth_panel, "Connect your horizOn project", 23)
	StormUI.label(auth_panel, "Online play adds cloud saves, boards, profiles and server-validated runs. Import your SDK config in the editor to connect.", 16, StormUI.MUTED)
	name_input = StormUI.input(auth_panel, "Display name")
	online_button = StormUI.button(auth_panel, "Connect and play as guest", _on_guest_pressed)
	var email_form := VBoxContainer.new()
	email_form.visible = false
	StormUI.button(auth_panel, "Email sign in / create account", func(): email_form.visible = not email_form.visible)
	auth_panel.add_child(email_form)
	var email_row := HBoxContainer.new()
	email_form.add_child(email_row)
	email_input = StormUI.input(email_row, "Email")
	email_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	password_input = StormUI.input(email_row, "Password", true)
	password_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buttons := HBoxContainer.new()
	email_form.add_child(buttons)
	StormUI.button(buttons, "Email sign in", func(): _email_auth(false))
	StormUI.button(buttons, "Create account", func(): _email_auth(true))
	status_label = StormUI.label(auth_panel, "SDK %s • %s" % [Horizon.getVersion(), "configuration ready" if Horizon.isInitialized() else "no configuration imported"], 14, StormUI.MUTED)
	if not Horizon.isInitialized():
		online_button.disabled = true
		for child in buttons.get_children():
			child.disabled = true
	if Horizon.auth.isSignedIn():
		StormUI.button(auth_panel, "Sign out of this account", func():
			if GameManager.auth_in_progress():
				status_label.text = "Authentication is still finishing. Please try again."
				return
			Horizon.auth.signOut()
			status_label.text = "Signed out. Connect again to choose another player."
		)
	StormUI.label(page, "horizOn SDK example / Godot    •    One more run? One better build.", 14, StormUI.MUTED)

func _on_practice() -> void:
	_request_generation += 1
	GameManager.enter_practice()
	GameManager.go_to_hub()

func _on_guest_pressed() -> void:
	if _busy:
		return
	_busy = true
	_request_generation += 1
	var request := _request_generation
	var display_name := name_input.text.strip_edges()
	online_button.disabled = true
	status_label.text = "Connecting and signing in… Offline practice remains available."
	var ok: bool = await GameManager.authenticate("guest", "", "", display_name)
	if not is_instance_valid(self) or not is_inside_tree() or request != _request_generation:
		return
	if ok:
		GameManager.enter_online()
		GameManager.go_to_hub()
		return
	status_label.text = "Connection or sign in failed. Retry or enjoy offline practice."
	_busy = false
	online_button.disabled = false

func _email_auth(create: bool) -> void:
	if _busy:
		return
	if email_input.text.strip_edges().is_empty() or password_input.text.is_empty():
		status_label.text = "Enter your email and password."
		return
	_busy = true
	_request_generation += 1
	var request := _request_generation
	var email := email_input.text.strip_edges()
	var password := password_input.text
	var display_name := name_input.text.strip_edges()
	status_label.text = "Connecting and authenticating… Offline practice remains available."
	var ok: bool = await GameManager.authenticate("create" if create else "email", email, password, display_name)
	if not is_instance_valid(self) or not is_inside_tree() or request != _request_generation:
		return
	if ok:
		GameManager.enter_online()
		GameManager.go_to_hub()
		return
	status_label.text = "Authentication failed. Check credentials and project configuration."
	_busy = false
