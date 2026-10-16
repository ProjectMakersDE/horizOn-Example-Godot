## Exercises the real bundled SDK transport against loopback synthetic responses.
extends SceneTree

var failures: Array[String] = []
var _stale_auth_result := true

func _initialize() -> void:
	call_deferred("_run")
	call_deferred("_watchdog")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	await process_frame
	var horizon = root.get_node("Horizon")
	var manager = root.get_node("GameManager")
	var fixture := OS.get_environment("SEAGULL_FIXTURE_URL")
	check(fixture.begins_with("http://127.0.0.1:"), "Fixture must be local loopback")
	if not failures.is_empty():
		quit(1)
		return
	horizon._http.activeHost = fixture
	horizon._http.apiKey = "synthetic-api-key"
	horizon._http.setSessionToken("synthetic-player-session")
	horizon._http.maxRetryAttempts = 1
	horizon._isConnected = true
	horizon._http._status = HorizonHttpClient.ConnectionStatus.CONNECTED
	check(await horizon.auth.signInEmail("qa@example.invalid", "synthetic-password"), "Email sign-in uses SDK transport against loopback fixture")
	horizon._config = HorizonConfig.new()
	horizon._config.api_key = "synthetic-api-key"
	manager.enter_online()
	await preload("res://tests/statistics_fixture_smoke.gd").run(self, check)
	manager._save_path = "user://seagull_fixture_qa.json"
	manager.selected_board = "storm"
	await manager.load_save_data()
	check(manager.save_data.coins == 77, "Cloud save deserializes actual SDK response")
	check(await manager.save_data_to_cloud(), "Cloud save uses authenticated transport")
	check(manager.buy_upgrade("speed"), "First cloud upgrade is affordable after load")
	manager.save_data_to_cloud()
	check(manager.buy_upgrade("speed"), "Second cloud upgrade charges the next price")
	check(await manager.save_data_to_cloud() and manager.save_data.coins == 42, "Concurrent full snapshots save in order without losing purchases")
	# The panel sends only explicit actions and retries one persisted command.
	var values_panel := preload("res://scripts/ui/player_values_demo.gd").new()
	root.add_child(values_panel)
	await process_frame
	await values_panel._load()
	check(values_panel._catalogue.size() == 1 and values_panel._output.text.contains("gold: 100"), "Values panel reads authoritative balances and offers")
	var practice_coins: int = manager.save_data.coins
	await values_panel._purchase()
	var pending_store := PlayerValueIntentStore.new(values_panel._scope())
	check(not pending_store.exists() and values_panel._offer_info.text.contains("gold 11"), "Changed offer refreshes the displayed price without booking")
	await values_panel._purchase()
	var original := pending_store.read()
	check(not original.is_empty(), "Lost purchase response retains persisted intent")
	var original_host: String = horizon._http.activeHost
	horizon._http.activeHost = "http://regional-failover.example.invalid"
	check(PlayerValueIntentStore.new(values_panel._scope()).read().operationId == original.operationId, "Regional host failover retains original persisted command")
	horizon._http.activeHost = original_host
	await values_panel._purchase()
	check(pending_store.read().operationId == original.operationId, "New purchase cannot replace unknown original command")
	for attempt in range(3):
		if not pending_store.exists():
			break
		await values_panel._retry()
	check(not pending_store.exists() and values_panel._output.text.contains("gold: 90"), "Explicit retries confirm original command and replace server snapshot")
	await values_panel._adjust()
	check(values_panel._output.text.contains("gold: 91"), "Explicit adjustment uses current server response")
	await values_panel._adjust()
	check(not pending_store.exists() and values_panel._status.text.contains("nothing booked"), "First-send authoritative refusal permits a new explicit action")
	await values_panel._adjust()
	var expired := pending_store.read()
	check(not expired.is_empty() and values_panel._status.text.contains("OPERATION_EXPIRED"), "Expired command stays blocked with original ID")
	await values_panel._retry()
	check(pending_store.read().operationId == expired.operationId, "Later refusal cannot clear a previously uncertain command")
	# Deliberate QA-only cleanup isolates the next transport scenario.
	check(pending_store.confirm(expired.operationId), "Fixture clears only its own expired command")
	await values_panel._adjust()
	check(pending_store.exists(), "Internal network retry prevents clearing even a final authoritative refusal")
	check(manager.save_data.coins == practice_coins, "Server values never alter practice/cloud upgrade coins")
	values_panel.queue_free()
	await process_frame
	var boards: Array = await horizon.leaderboard.listBoards()
	check(boards.size() == 2 and boards[1].validatedOnly, "Boards preserve validated-only option")
	var entries: Array = await horizon.leaderboard.getTop(10, false, "storm")
	check(entries.size() == 1 and entries[0].username == "QA Seagull", "Top leaderboard parses current model")
	entries = await horizon.leaderboard.getAround(5, false, "storm")
	check(entries.size() == 1, "Around-me query works")
	var rank = await horizon.leaderboard.getRank("storm")
	check(rank != null and rank.position == 2, "Rank uses selected board")
	check(not await horizon.leaderboard.submitScore(100, "validated"), "Validated-only board rejects normal submit")
	check(horizon.leaderboard.getLastErrorCode() == "VALIDATED_SUBMIT_REQUIRED", "Typed refusal stays visible")
	manager.validation_requested = true
	check(await manager.validated_run.begin(), "Recorder obtains a real SDK run ticket")
	manager.validated_run.record_move(Vector2.RIGHT)
	manager.validated_run.record_dash()
	manager.validated_run.record_levelup_choice(1)
	var accepted: Dictionary = await manager.validated_run.finish(100, "wave_2")
	check(accepted.get("accepted", false), "Accepted validated response is parsed")
	await create_timer(0.4).timeout
	check(manager.validated_run.last_message.contains("evidence uploaded"), "Automatic evidence upload status reaches the game")
	var accepted_message: String = manager.validated_run.last_message
	manager.validated_run._on_evidence_uploaded("old-run-id")
	check(manager.validated_run.last_message == accepted_message, "Stale evidence callback cannot change current result")
	check(await manager.validated_run.begin(), "Oversized input test obtains ticket")
	manager.validated_run._truncated = true
	check((await manager.validated_run.finish(100, "wave_2")).is_empty() and manager.validated_run.last_error_code == "INPUT_LOG_INCOMPLETE", "Truncated evidence refuses validated submission locally")
	manager.selected_board = "tiny-evidence"
	check(await manager.validated_run.begin(), "Early evidence fixture issues ticket")
	await manager.validated_run.finish(100, "wave_2")
	check(manager.validated_run.last_message.contains("EVIDENCE_TOO_LARGE"), "Synchronous evidence failure survives accepted submit message")
	manager.selected_board = "reject"
	check(await manager.validated_run.begin(), "Reject fixture still issues a ticket")
	var rejected: Dictionary = await manager.validated_run.finish(100, "wave_2")
	check(rejected.is_empty() and manager.validated_run.last_error_code == "DURATION_TOO_SHORT", "Rejected run reports exact server reason")
	var news: Array = await horizon.news.loadNews(5, "en")
	check(news.size() == 1 and news[0].message == "Fixture news", "News uses message field")
	var profile: Dictionary = await horizon.playerProfile.getProfile()
	check(not profile.is_empty() and horizon.playerProfile.isAvailable("seagull"), "Profile catalog availability works")
	check(not (await horizon.playerProfile.setProfile("seagull", "", [])).is_empty(), "Profile applies unlocked avatar")
	var state: Dictionary = await horizon.validatedActions.getState()
	check(state.get("values", []).size() == 1, "Server-owned values remain separate")
	var config: Dictionary = await horizon.remoteConfig.getAllConfigs(false)
	check(config.get("run_duration_seconds") == "180", "Remote config parses scalar key")
	var words: Dictionary = await horizon.localization.getAllLocalizations("de")
	manager.language = "de"
	manager.translations = words
	check(manager.ui_text("seagull.play", "Launch") == "Fixture spielen", "SDK localization affects actual UI label")
	check(await horizon.giftCodes.validate("QA-GIFT") == true, "Gift validation works")
	check((await horizon.giftCodes.redeem("QA-GIFT")).get("success", false), "Synthetic gift redemption works")
	check(await horizon.feedback.submit("Fixture", "Synthetic QA feedback", "GENERAL", "", false), "Feedback transport works")
	check(not (await horizon.userLogs.info("Synthetic QA run")).is_empty(), "User Logs transport works")
	check(await horizon.crashes.register_session(), "Crash session transport works")
	var email: Dictionary = await horizon.email_sending.send_email("qa-player", "qa-template", {}, "en")
	check(email.get("id") == "synthetic-email", "Email fixture queues only on loopback")
	check((await horizon.email_sending.get_email_status("synthetic-email")).get("status") == "QUEUED", "Email status transport works")
	manager.selected_board = "delayed"
	manager.start_run()
	manager.go_to_title()
	await create_timer(0.5).timeout
	check(current_scene.has_method("_on_practice"), "Leaving during ticket request cannot override navigation")
	check(not manager.validated_run.is_active(), "Canceled start drops late ticket")
	# Authentication is serialized across recreated title instances.
	_stale_auth(manager)
	manager.enter_practice()
	check(await manager.authenticate("email", "new-player@example.invalid", "synthetic-password"), "New title authentication waits for an older request")
	manager.enter_online()
	check(not _stale_auth_result and horizon.getCurrentUser().userId == "new-player", "Late authentication cannot replace the newer identity")
	check(manager._save_path.contains("new-player".sha256_text().substr(0, 16)), "New identity owns its cache path")
	# Late cloud/config responses must not mutate a new practice state.
	horizon.getCurrentUser().userId = "slow-player"
	manager.enter_online()
	manager.load_save_data()
	manager.save_data.coins = 99
	check(not manager.buy_upgrade("speed"), "Purchases remain locked until initial cloud load")
	var config_cache = root.get_node("ConfigCache")
	horizon.remoteConfig.clearCache()
	config_cache.load_all()
	manager.enter_practice()
	manager.save_data.coins = 13
	await create_timer(0.5).timeout
	check(manager.save_data.coins == 13 and not manager._cloud_ready, "Late cloud load cannot overwrite practice state")
	check(not config_cache.is_loaded() and config_cache.get_float("run_duration_seconds", 180.0) == 180.0, "Late config load cannot overwrite practice defaults")
	# A refused ticket must switch economy and config before scene creation.
	horizon.getCurrentUser().userId = "qa-player"
	manager.enter_online()
	manager.selected_board = "no-ticket"
	manager.validation_requested = true
	manager.start_run()
	manager.validation_requested = false
	manager.selected_board = "storm"
	await create_timer(0.5).timeout
	await process_frame
	check(manager.practice_mode and not manager.validation_requested, "Failed ticket switches to isolated practice")
	check(manager._save_path == "user://practice_save.json", "Failed ticket uses practice save path")
	await manager.end_run()
	await process_frame
	check(manager.submission_status.contains("no leaderboard"), "Failed ticket never sends account score/rewards")
	# Transient restoration must keep the valuable identity, never create another guest.
	horizon.auth.signOut(false)
	horizon.auth._saveAnonymousToken("restore-fails")
	check(not await manager.authenticate("guest"), "Failed anonymous restore fails closed")
	check(horizon.auth.getCachedAnonymousToken() == "restore-fails", "Failed restore retains original anonymous identity")
	var legacy := "x".repeat(36)
	horizon.auth._saveAnonymousToken(legacy)
	check(not await manager.authenticate("guest") and not await manager.authenticate("guest"), "Repeated legacy-token restore refuses replacement identity")
	check(horizon.auth._loadFromStorage(HorizonAuth.CACHE_KEY_ANONYMOUS_TOKEN) == legacy, "Legacy token remains intact without destructive SDK getter")
	DirAccess.remove_absolute("user://seagull_fixture_qa.json")
	if failures.is_empty():
		print("SDK_FIXTURE_SMOKE_PASS: cloud, boards/top/around/rank, validated accept/reject/evidence, profile, state, config, localization, gift, feedback, logs, crashes, email")
	root.get_node("AudioManager").shutdown()
	await create_timer(0.15).timeout
	call_deferred("quit",0 if failures.is_empty() else 1)

func _stale_auth(manager: Node) -> void:
	_stale_auth_result = await manager.authenticate("email", "slow-player@example.invalid", "synthetic-password")

func _watchdog() -> void:
	await create_timer(30.0).timeout
	push_error("SDK fixture exceeded30sec watchdog")
	quit(1)
