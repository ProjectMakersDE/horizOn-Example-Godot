## Feedback Popup - Submit feedback to horizOn
extends PanelContainer

@onready var title_input: LineEdit = $VBox/TitleInput
@onready var message_input: TextEdit = $VBox/MessageInput
@onready var category_option: OptionButton = $VBox/CategoryOption
@onready var submit_button: Button = $VBox/SubmitButton
@onready var close_button: Button = $VBox/CloseButton
@onready var status_label: Label = $VBox/StatusLabel


func _ready() -> void:
	category_option.add_item("BUG", 0)
	category_option.add_item("FEATURE_REQUEST", 1)
	category_option.add_item("GENERAL", 2)

	submit_button.pressed.connect(_on_submit)
	close_button.pressed.connect(func(): visible = false)
	status_label.text = ""


func _on_submit() -> void:
	var title := title_input.text.strip_edges()
	var message := message_input.text.strip_edges()
	if title.is_empty() or message.is_empty():
		status_label.text = "Fill in title and message."
		return

	var category := category_option.get_item_text(category_option.selected)

	status_label.text = "Submitting..."
	submit_button.disabled = true

	var success := await Horizon.feedback.submit(title, message, category)
	if success:
		status_label.text = "Feedback sent!"
		title_input.text = ""
		message_input.text = ""
		Horizon.crashes.record_breadcrumb("user_action", "submitted_feedback")
	else:
		status_label.text = "Failed to send feedback."

	submit_button.disabled = false
