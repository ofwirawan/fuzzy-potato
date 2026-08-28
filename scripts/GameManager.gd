class_name GameManager
extends Control

enum GameState {
	DRAWING_PHASE,
	DEALER_ACCUSATION,
	SHOWDOWN,
	GAME_OVER
}

var current_state: GameState = GameState.GAME_OVER
var players: Array[Player] = []
var dealer_index: int = -1
var current_dealer: Player
var current_turn_player: Player
var current_turn_index: int = -1

@export_group("Core Managers")
@export_node_path("Node") var deck_manager: NodePath

@export_group("Global UI")
@export_node_path("Label") var status_label: NodePath
@export_node_path("Container") var target_selection_container: NodePath
@export_node_path("Button") var restart_button: NodePath

@export_group("Action Controls")
@export_node_path("Button") var hit_button: NodePath
@export_node_path("Button") var stand_button: NodePath
@export_node_path("Button") var skip_button: NodePath

var _deck_manager: DeckManager
var _status_label: Label
var _target_selection_container: Container
var _hit_button: Button
var _stand_button: Button
var _skip_button: Button
var _restart_button: Button


func _ready() -> void:
	_resolve_node_references()
	_connect_signals()
	setup_game()


func _resolve_node_references() -> void:
	_deck_manager = get_node_or_null(deck_manager) as DeckManager
	_status_label = get_node_or_null(status_label) as Label
	_target_selection_container = get_node_or_null(target_selection_container) as Container
	_hit_button = get_node_or_null(hit_button) as Button
	_stand_button = get_node_or_null(stand_button) as Button
	_skip_button = get_node_or_null(skip_button) as Button
	_restart_button = get_node_or_null(restart_button) as Button


func _connect_signals() -> void:
	if _hit_button:
		_hit_button.pressed.connect(_on_hit_pressed)
	if _stand_button:
		_stand_button.pressed.connect(_on_stand_pressed)
	if _skip_button:
		_skip_button.pressed.connect(_on_skip_pressed)
	if _restart_button:
		_restart_button.pressed.connect(start_new_round)


func setup_game() -> void:
	players.clear()
	players.append(Player.new(1, "Player 1", $UI/PlayerContainers/P1, $UI/PlayerLabels/P1Label))
	players.append(Player.new(2, "Player 2", $UI/PlayerContainers/P2, $UI/PlayerLabels/P2Label))
	players.append(Player.new(3, "Player 3", $UI/PlayerContainers/P3, $UI/PlayerLabels/P3Label))
	players.append(Player.new(4, "Player 4", $UI/PlayerContainers/P4, $UI/PlayerLabels/P4Label))
	dealer_index = -1
	start_new_round()


func start_new_round() -> void:
	if players.is_empty() or not _deck_manager:
		return
	current_state = GameState.DRAWING_PHASE
	for player in players:
		player.reset_round()

	dealer_index = (dealer_index + 1) % players.size()
	current_dealer = players[dealer_index]
	current_dealer.is_dealer = true
	_deck_manager.reset_deck()

	for player in players:
		player.add_card(_deck_manager.draw_card(), true)
		player.add_card(_deck_manager.draw_card(), true)

	current_turn_index = (dealer_index + 1) % players.size()
	current_turn_player = players[current_turn_index]
	_set_status("%s is the Dealer! %s's turn to draw." % [current_dealer.name, current_turn_player.name])
	_update_all_score_labels()
	_update_ui_state()


func _on_hit_pressed() -> void:
	if current_state != GameState.DRAWING_PHASE or current_turn_player == null:
		return
	current_turn_player.add_card(_deck_manager.draw_card(), true)
	_update_all_score_labels()


func _on_stand_pressed() -> void:
	if current_state == GameState.DRAWING_PHASE:
		_advance_turn()


func _advance_turn() -> void:
	var next_index := (current_turn_index + 1) % players.size()
	while players[next_index].is_dealer or players[next_index].is_eliminated:
		next_index = (next_index + 1) % players.size()
		if next_index == current_turn_index:
			_start_dealer_phase()
			return
	current_turn_index = next_index
	current_turn_player = players[current_turn_index]
	_set_status("%s's turn to draw or stand." % current_turn_player.name)


func _start_dealer_phase() -> void:
	current_state = GameState.DEALER_ACCUSATION
	while current_dealer.calculate_score(_deck_manager) < 17:
		current_dealer.add_card(_deck_manager.draw_card(), true)
	_set_status("Accusation Phase: %s, choose a player to check or skip." % current_dealer.name)
	_populate_target_buttons()
	_update_all_score_labels()
	_update_ui_state()


func _populate_target_buttons() -> void:
	if not _target_selection_container:
		return
	for child in _target_selection_container.get_children():
		child.free()
	for player in players:
		if player == current_dealer or player.is_eliminated:
			continue
		var button := Button.new()
		button.text = "Check " + player.name
		button.pressed.connect(dealer_check_player.bind(player))
		_target_selection_container.add_child(button)


func dealer_check_player(target_player: Player) -> void:
	if current_state != GameState.DEALER_ACCUSATION or target_player == null:
		return
	if target_player.is_busted(_deck_manager):
		_set_status("Exposed! %s was over 21." % target_player.name)
		_steal_card(target_player, current_dealer)
		target_player.is_eliminated = true
	else:
		_set_status("Wrong call! %s was safe." % target_player.name)
		current_dealer.add_card(_deck_manager.draw_card(), true)
		_steal_card(current_dealer, target_player)
	resolve_showdown()


func _on_skip_pressed() -> void:
	if current_state != GameState.DEALER_ACCUSATION:
		return
	_set_status("Dealer skipped the accusation.")
	resolve_showdown()


func _steal_card(from_player: Player, to_player: Player) -> void:
	if from_player.hand.is_empty():
		return
	to_player.hand.append(from_player.hand.pop_back())
	from_player.refresh_hand_visuals(true)
	to_player.refresh_hand_visuals(true)


func resolve_showdown() -> void:
	current_state = GameState.SHOWDOWN
	for player in players:
		player.reveal_hand()
	_update_all_score_labels(true)

	var dealer_score := current_dealer.calculate_score(_deck_manager)
	var winners: Array[Player] = []
	for player in players:
		if player == current_dealer or player.is_eliminated:
			continue
		var score := player.calculate_score(_deck_manager)
		if score <= 21 and (dealer_score > 21 or score > dealer_score):
			winners.append(player)

	if winners.is_empty():
		_end_game("Dealer (%s) wins the round!" % current_dealer.name)
	else:
		var names: Array[String] = []
		for winner in winners:
			names.append(winner.name)
		_end_game("Winners: " + ", ".join(names))


func _end_game(message: String) -> void:
	current_state = GameState.GAME_OVER
	_set_status(message)
	_update_ui_state()


func _update_all_score_labels(show_full: bool = false) -> void:
	var local_peer_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for player in players:
		var show_score := show_full or player.peer_id == local_peer_id
		player.update_score_display(player.calculate_score(_deck_manager) if show_score else -1)


func _update_ui_state() -> void:
	var drawing := current_state == GameState.DRAWING_PHASE
	var accusation := current_state == GameState.DEALER_ACCUSATION
	if _hit_button:
		_hit_button.visible = drawing
	if _stand_button:
		_stand_button.visible = drawing
	if _skip_button:
		_skip_button.visible = accusation
	if _target_selection_container:
		_target_selection_container.visible = accusation
	if _restart_button:
		_restart_button.visible = current_state == GameState.GAME_OVER


func _set_status(message: String) -> void:
	if _status_label:
		_status_label.text = message
