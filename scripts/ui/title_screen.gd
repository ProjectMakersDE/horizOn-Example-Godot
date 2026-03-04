## Title Screen - Authentication and entry point
extends Control

@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var email_input: LineEdit = $VBoxContainer/EmailInput
@onready var password_input: LineEdit = $VBoxContainer/PasswordInput
@onready var guest_button: Button = $VBoxContainer/GuestButton
@onready var email_signin_button: Button = $VBoxContainer/EmailSignInButton
@onready var create_account_button: Button = $VBoxContainer/CreateAccountButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var email_fields: VBoxContainer = $VBoxContainer/EmailFields


func _ready() -> void:
	AudioManager.play_music("music_menu")
	email_fields.visible = false
	status_label.text = ""

	guest_button.pressed.connect(_on_guest_pressed)
	email_signin_button.pressed.connect(_on_email_signin_pressed)
	create_account_button.pressed.connect(_on_create_account_pressed)

	# Connect to server
	_connect_to_server()


func _connect_to_server() -> void:
	status_label.text = "Connecting..."
	_set_buttons_disabled(true)

	var success := await Horizon.connect_to_server()
	if success:
		status_label.text = "Connected!"
		# Try to restore session
		if Horizon.auth.hasCachedAnonymousToken():
			status_label.text = "Restoring session..."
			var restored := await Horizon.auth.restoreAnonymousSession()
			if restored:
				_go_to_hub()
				return

		_set_buttons_disabled(false)
		status_label.text = "Welcome to Seagull Storm!"
	else:
		status_label.text = "Connection failed. Retry..."
		await get_tree().create_timer(2.0).timeout
		_connect_to_server()


func _on_guest_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		player_name = "Seagull_%d" % (randi() % 9999)

	_set_buttons_disabled(true)
	status_label.text = "Signing in as guest..."

	var success := await Horizon.quickSignInAnonymous(player_name)
	if success:
		GameManager.display_name = Horizon.getCurrentUser().displayName
		GameManager.is_signed_in = true
		# Register crash session
		await Horizon.crashes.register_session()
		Horizon.crashes.record_breadcrumb("navigation", "signed_in_guest")
		_go_to_hub()
	else:
		status_label.text = "Sign in failed. Try again."
		_set_buttons_disabled(false)


func _on_email_signin_pressed() -> void:
	if not email_fields.visible:
		email_fields.visible = true
		email_signin_button.text = "Sign In"
		return

	var email := email_input.text.strip_edges()
	var password := password_input.text.strip_edges()
	if email.is_empty() or password.is_empty():
		status_label.text = "Enter email and password."
		return

	_set_buttons_disabled(true)
	status_label.text = "Signing in..."

	var success := await Horizon.auth.signInEmail(email, password)
	if success:
		GameManager.display_name = Horizon.getCurrentUser().displayName
		GameManager.is_signed_in = true
		await Horizon.crashes.register_session()
		Horizon.crashes.record_breadcrumb("navigation", "signed_in_email")
		_go_to_hub()
	else:
		status_label.text = "Sign in failed. Check credentials."
		_set_buttons_disabled(false)


func _on_create_account_pressed() -> void:
	if not email_fields.visible:
		email_fields.visible = true
		create_account_button.text = "Create"
		return

	var player_name := name_input.text.strip_edges()
	var email := email_input.text.strip_edges()
	var password := password_input.text.strip_edges()
	if email.is_empty() or password.is_empty():
		status_label.text = "Enter email and password."
		return
	if player_name.is_empty():
		player_name = "Seagull_%d" % (randi() % 9999)

	_set_buttons_disabled(true)
	status_label.text = "Creating account..."

	var success := await Horizon.auth.signUpEmail(email, password, player_name)
	if success:
		GameManager.display_name = Horizon.getCurrentUser().displayName
		GameManager.is_signed_in = true
		await Horizon.crashes.register_session()
		Horizon.crashes.record_breadcrumb("navigation", "signed_up_email")
		_go_to_hub()
	else:
		status_label.text = "Account creation failed."
		_set_buttons_disabled(false)


func _set_buttons_disabled(disabled: bool) -> void:
	guest_button.disabled = disabled
	email_signin_button.disabled = disabled
	create_account_button.disabled = disabled


func _go_to_hub() -> void:
	Horizon.crashes.record_breadcrumb("navigation", "entered_hub")
	get_tree().change_scene_to_file("res://scenes/hub/hub_screen.tscn")
