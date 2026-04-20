## Title Screen - Authentication and entry point
extends Control

@onready var name_input: LineEdit = $VBoxContainer/NameInput
@onready var email_input: LineEdit = $VBoxContainer/EmailFields/EmailInput
@onready var password_input: LineEdit = $VBoxContainer/EmailFields/PasswordInput
@onready var guest_button: Button = $VBoxContainer/GuestButton
@onready var email_signin_button: Button = $VBoxContainer/EmailSignInButton
@onready var create_account_button: Button = $VBoxContainer/CreateAccountButton
@onready var google_button: Button = $VBoxContainer/GoogleButton
@onready var apple_button: Button = $VBoxContainer/AppleButton
@onready var status_label: Label = $VBoxContainer/StatusLabel
@onready var email_fields: VBoxContainer = $VBoxContainer/EmailFields


func _ready() -> void:
	AudioManager.play_music("music_menu")
	email_fields.visible = false
	status_label.text = ""

	guest_button.pressed.connect(_on_guest_pressed)
	email_signin_button.pressed.connect(_on_email_signin_pressed)
	create_account_button.pressed.connect(_on_create_account_pressed)
	google_button.pressed.connect(_on_google_pressed)
	apple_button.pressed.connect(_on_apple_pressed)

	_connect_to_server()


func _connect_to_server() -> void:
	status_label.text = "Connecting..."
	_set_buttons_disabled(true)

	var success := await Horizon.connect_to_server()
	if success:
		status_label.text = "Connected!"

		# Check if already signed in (e.g. cached email session)
		if Horizon.auth.isSignedIn():
			status_label.text = "Checking session..."
			var valid := await Horizon.auth.checkAuth()
			if valid:
				GameManager.go_to_hub()
				return

		# Try to restore anonymous session
		if Horizon.auth.hasCachedAnonymousToken():
			status_label.text = "Restoring session..."
			var restored := await Horizon.auth.restoreAnonymousSession()
			if restored:
				GameManager.go_to_hub()
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
		Horizon.crashes.record_breadcrumb("navigation", "signed_in_guest")
		GameManager.go_to_hub()
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
		Horizon.crashes.record_breadcrumb("navigation", "signed_in_email")
		GameManager.go_to_hub()
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
		Horizon.crashes.record_breadcrumb("navigation", "signed_up_email")
		GameManager.go_to_hub()
	else:
		status_label.text = "Account creation failed."
		_set_buttons_disabled(false)


func _on_google_pressed() -> void:
	# Google OAuth requires a platform-specific authorization code flow.
	# Attempt the SDK call; if it fails (e.g. no OAuth code), inform the user.
	_set_buttons_disabled(true)
	status_label.text = "Attempting Google Sign-In..."

	# The SDK's signInGoogle() requires an authorization code and redirect URI
	# which must be obtained from a platform-specific OAuth flow (e.g. browser redirect).
	# On platforms without that flow, this will fail gracefully.
	var auth_code := ""  # Would be populated by platform OAuth flow
	var redirect_uri := ""
	if auth_code.is_empty():
		status_label.text = "Google Sign-In is not available on this platform."
		_set_buttons_disabled(false)
		return

	var success := await Horizon.auth.signInGoogle(auth_code, redirect_uri)
	if success:
		Horizon.crashes.record_breadcrumb("navigation", "signed_in_google")
		GameManager.go_to_hub()
	else:
		status_label.text = "Google Sign-In failed. Try another method."
		_set_buttons_disabled(false)


func _on_apple_pressed() -> void:
	# Apple Sign-In: native sheet on iOS via the bundled .gdip plugin,
	# system-browser OAuth fallback on every other platform. The fallback
	# requires the customer to register a Services ID in their horizOn API key
	# and to provide it here.
	_set_buttons_disabled(true)
	status_label.text = "Attempting Apple Sign-In..."

	var services_id := ""  # Provide your Apple Services ID here for non-iOS builds.
	var success := await Horizon.auth.sign_in_with_apple(services_id)
	if success:
		Horizon.crashes.record_breadcrumb("navigation", "signed_in_apple")
		GameManager.go_to_hub()
	else:
		status_label.text = "Apple Sign-In is not available on this platform."
		_set_buttons_disabled(false)


func _set_buttons_disabled(disabled: bool) -> void:
	guest_button.disabled = disabled
	email_signin_button.disabled = disabled
	create_account_button.disabled = disabled
	google_button.disabled = disabled
	apple_button.disabled = disabled
