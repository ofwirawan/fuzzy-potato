class_name GameManager
extends Node

# --- Enums & States ---
enum GameState {
	DRAWING_PHASE,
	DEALER_ACCUSATION,
	SHOWDOWN,
	GAME_OVER
}

var current_state: GameState = GameState.DRAWING_PHASE

# --- Player & Role Tracking ---
var players: Array[Player] = []
var dealer_index: int = 0
var current_dealer: Player = null
var current_turn_index: int = 0
var current_turn_player: Player = null

# --- Node References ---
@export_group("Core Managers")
@export var deck_manager: DeckManager

@export_group("Global UI")
@export var status_label: Label
@export var target_selection_container: Container # Container for dynamic target buttons
@export var restart_button: Button

@export_group("Action Controls")
@export var hit_button: Button
@export var stand_button: Button
@export var skip_button: Button


func _ready() -> void:
	_connect_signals()
	setup_game()


func _connect_signals() -> void:
	if hit_button: hit_button.pressed.connect(_on_hit_pressed)
	if stand_button: stand_button.pressed.connect(_on_stand_pressed)
	if skip_button: skip_button.pressed.connect(_on_skip_pressed)
	if restart_button: restart_button.pressed.connect(start_new_round)


# ==============================================================================
# INITIALIZATION & ROUND SETUP
# ==============================================================================

func setup_game() -> void:
	# Register players (Pass container and label references from UI nodes)
	# For networked multiplayer, pass actual peer IDs instead of 1, 2, 3, 4
	players.clear()
	players.append(Player.new(1, "Player 1", $UI/PlayerContainers/P1, $UI/PlayerLabels/P1Label))
	players.append(Player.new(2, "Player 2", $UI/PlayerContainers/P2, $UI/PlayerLabels/P2Label))
	players.append(Player.new(3, "Player 3", $UI/PlayerContainers/P3, $UI/PlayerLabels/P3Label))
	players.append(Player.new(4, "Player 4", $UI/PlayerContainers/P4, $UI/PlayerLabels/P4Label))
	
	dealer_index = 0
	start_new_round()


func start_new_round() -> void:
	current_state = GameState.DRAWING_PHASE
	
	# 1. Reset all player states and clear hands
	for p in players:
		p.reset_round()

	# 2. Assign and Rotate Dealer Role
	if current_dealer:
		current_dealer.is_dealer = false
		
	current_dealer = players[dealer_index]
	current_dealer.is_dealer = true
	dealer_index = (dealer_index + 1) % players.size()

	# 3. Reset turn order to first non-dealer player
	current_turn_index = (dealer_index) % players.size()
	current_turn_player = players[current_turn_index]

	if deck_manager:
		deck_manager.reset_deck()

	# 4. Deal initial 2 face-down cards to EVERY player
	for p in players:
		p.add_card(deck_manager.draw_card(), true)
		p.add_card(deck_manager.draw_card(), true)

	status_label.text = current_dealer.name + " is the Dealer! " + current_turn_player.name + "'s turn to draw."
	_update_all_score_labels()
	_update_ui_state()


# ==============================================================================
# PHASE 1: DRAWING PHASE
# ==============================================================================

func _on_hit_pressed() -> void:
	if current_state != GameState.DRAWING_PHASE: return
	
	# Turn player draws a face-down card (No automatic bust check!)
	var card = deck_manager.draw_card()
	current_turn_player.add_card(card, true)
	_update_all_score_labels()


func _on_stand_pressed() -> void:
	if current_state != GameState.DRAWING_PHASE: return
	
	# Advance turn to next player (skipping the dealer)
	_advance_turn()


func _advance_turn() -> void:
	current_turn_index = (current_turn_index + 1) % players.size()
	current_turn_player = players[current_turn_index]

	# If turn cycles back to dealer, non-dealers have finished drawing
	if current_turn_player == current_dealer:
		_start_dealer_phase()
	else:
		status_label.text = current_turn_player.name + "'s turn to draw or stand."


func _start_dealer_phase() -> void:
	current_state = GameState.DEALER_ACCUSATION
	
	# Dealer automatically draws cards until hand total >= 17
	while current_dealer.calculate_score(deck_manager) < 17:
		current_dealer.add_card(deck_manager.draw_card(), true)

	status_label.text = "Accusation Phase: " + current_dealer.name + ", choose a player to Check or Skip."
	_populate_target_buttons()
	_update_ui_state()


# ==============================================================================
# PHASE 2: DEALER ACCUSATION & PUNISHMENTS
# ==============================================================================

func _populate_target_buttons() -> void:
	# Clear existing dynamic target buttons
	if not target_selection_container: return
	for child in target_selection_container.get_children():
		child.queue_free()

	# Create a target button for every non-dealer player
	for p in players:
		if p == current_dealer or p.is_eliminated: continue
		
		var btn = Button.new()
		btn.text = "Check " + p.name
		btn.pressed.connect(func(): dealer_check_player(p))
		target_selection_container.add_child(btn)


func dealer_check_player(target_player: Player) -> void:
	if current_state != GameState.DEALER_ACCUSATION: return

	if target_player.is_busted(deck_manager):
		# CORRECT ACCUSATION: Target was over 21
		status_label.text = "Exposed! " + target_player.name + " was over 21!"
		_steal_card(target_player, current_dealer)
		target_player.is_eliminated = true
	else:
		# INCORRECT ACCUSATION: Target was valid (<= 21)
		status_label.text = "Wrong Call! " + target_player.name + " is valid!"
		current_dealer.add_card(deck_manager.draw_card(), true) # Penalty draw
		_steal_card(current_dealer, target_player)

	resolve_showdown()


func _on_skip_pressed() -> void:
	if current_state != GameState.DEALER_ACCUSATION: return
	
	status_label.text = "Dealer Skipped! Unchosen valid players gain rewards."
	_reward_unchosen_players()
	resolve_showdown()


func _steal_card(from_player: Player, to_player: Player) -> void:
	if from_player.hand.size() > 0:
		var stolen_card = from_player.hand.pop_back()
		to_player.hand.append(stolen_card)


func _reward_unchosen_players() -> void:
	for p in players:
		if p != current_dealer and not p.is_busted(deck_manager):
			print("Awarded bonus to " + p.name)


# ==============================================================================
# PHASE 3: SHOWDOWN & RESOLUTION
# ==============================================================================

func resolve_showdown() -> void:
	current_state = GameState.SHOWDOWN
	
	# 1. Reveal all hands face-up
	for p in players:
		p.reveal_hand()

	_update_all_score_labels(true)

	# 2. Evaluate final scores post-steals
	var dealer_score = current_dealer.calculate_score(deck_manager)
	var dealer_busted = dealer_score > 21

	var winners: Array[Player] = []

	for p in players:
		if p == current_dealer or p.is_eliminated:
			continue
			
		var score = p.calculate_score(deck_manager)
		# Late disqualification check: Must be <= 21 AND beat Dealer
		if score <= 21:
			if dealer_busted or score > dealer_score:
				winners.append(p)

	# 3. Announce round outcome
	if winners.size() > 0:
		var win_text = "Winners: "
		for w in winners: win_text += w.name + " "
		_end_game(win_text)
	else:
		_end_game("Dealer (" + current_dealer.name + ") wins the round!")


func _end_game(message: String) -> void:
	current_state = GameState.GAME_OVER
	status_label.text = message
	_update_ui_state()


# ==============================================================================
# UI HELPERS
# ==============================================================================

func _update_all_score_labels(show_full: bool = false) -> void:
	var local_peer_id = multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

	for p in players:
		# Reveal score if Showdown OR if local screen belongs to this player
		if show_full or p.peer_id == local_peer_id:
			p.update_score_display(p.calculate_score(deck_manager))
		else:
			p.update_score_display(-1) # Displays "?"


func _update_ui_state() -> void:
	var is_drawing = (current_state == GameState.DRAWING_PHASE)
	var is_accusation = (current_state == GameState.DEALER_ACCUSATION)
	var is_game_over = (current_state == GameState.GAME_OVER)

	if hit_button: hit_button.visible = is_drawing
	if stand_button: stand_button.visible = is_drawing
	if skip_button: skip_button.visible = is_accusation
	if target_selection_container: target_selection_container.visible = is_accusation
	if restart_button: restart_button.visible = is_game_over
