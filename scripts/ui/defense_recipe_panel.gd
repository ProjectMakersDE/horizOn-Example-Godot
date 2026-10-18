extends VBoxContainer
## Opened explicitly from either official Game or Hello. No startup request.
const Recipe = preload("res://scripts/recipes/defense_recipe.gd")
var _recipe: Node
var _challenge: TextEdit
var _output: TextEdit
var _hp: LineEdit
var _power: LineEdit

func _ready() -> void:
	_recipe = Recipe.new(); add_child(_recipe)
	StormUI.label(self, "World map / asynchronous defense", 23)
	StormUI.label(self, "Existing player session required. Configure the defenses collection and evidence board first. This client never sends a trusted notice or awards a win.", 15, StormUI.MUTED)
	_hp = StormUI.input(self, "Defense HP (mini-game 1–1000)"); _hp.text = "15"
	_power = StormUI.input(self, "Defense power (mini-game 1–1000)"); _power.text = "3"
	StormUI.button(self, "Read owner usage before storing defense", func(): _show(await _recipe.review_usage()))
	StormUI.button(self, "Store reviewed defense at map position 10,10", func():
		if not _hp.text.is_valid_int() or not _power.text.is_valid_int(): _show({"errorCode": "INTEGER_REQUIRED"}); return
		_show(await _recipe.publish_defense(int(_hp.text), int(_power.text), 10, 10)))
	StormUI.button(self, "Read one world-map rectangle page", func(): _show(await _recipe.read_map()))
	StormUI.button(self, "Read one opponent power sample", func(): _show(await _recipe.find_opponents()))
	StormUI.label(self, "Paste the public challenge JSON produced by the trusted operator CLI. Never paste its credential config.", 15)
	_challenge = TextEdit.new(); _challenge.custom_minimum_size.y = 120; add_child(_challenge)
	StormUI.button(self, "Save this reviewed trusted challenge (local only)", func(): _show(_recipe.import_challenge(_challenge.text)))
	StormUI.button(self, "Cancel only a never-started local challenge", func(): _show(_recipe.cancel_unsent_challenge()))
	StormUI.button(self, "Read original defense and start one validated run", func(): _show(await _recipe.start_reviewed_defense()))
	StormUI.button(self, "Attack (one explicit turn)", func(): _show(_recipe.play(0)))
	StormUI.button(self, "Guard (one explicit turn)", func(): _show(_recipe.play(1)))
	StormUI.button(self, "Submit the finished game and original input log", func(): _show(await _recipe.submit_finished_defense()))
	StormUI.button(self, "Retry only the original requested evidence upload", func(): _show(await _recipe.upload_original_evidence()))
	StormUI.button(self, "Inspect local original (no request)", func(): _show(_recipe.inspect()))
	StormUI.button(self, "Acknowledge confirmed local evidence (no notice claim)", func(): _show(_recipe.acknowledge_local_success()))
	StormUI.button(self, "Defender: read actual Inbox after trusted CLI delivery", func(): _show(await _recipe.read_inbox()))
	_output = TextEdit.new(); _output.editable = false; _output.custom_minimum_size.y = 240; add_child(_output)
	_output.text = "No network action has run. Unknown run starts/submits remain protected across restart."

func _show(result: Dictionary) -> void:
	if is_inside_tree(): _output.text = JSON.stringify(result, "  ")
