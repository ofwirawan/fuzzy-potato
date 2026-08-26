extends Node

enum GameState { BETTING, PLAYER_TURN, DEALER_TURN, GAME_OVER }
var current_state: GameState = GameState.BETTING

var player_hand: Array[CardData] = []
var dealer_hand: Array[CardData] = []

@onready var deck: DeckManager = $DeckManager
@onready var player_container: HBoxContainer = $UI/PlayerHand
@onready var dealer_container: HBoxContainer = $UI/DealerHand

# Button References
@onready var hit_button: Button = $UI/HBoxContainer/HitButton
@onready var stand_button: Button = $UI/HBoxContainer/StandButton
@onready var restart_button: Button = $UI/HBoxContainer/RestartButton

# Label References
@onready var status_label: Label = $UI/StatusLabel
@onready var player_score_label: Label = $UI/PlayerScoreLabel
@onready var dealer_score_label: Label = $UI/DealerScoreLabel

func _ready():
	# Connect UI button signals
	hit_button.pressed.connect(player_hit)
	stand_button.pressed.connect(player_stand)
	restart_button.pressed.connect(start_new_round)
	
	# Start the first round automatically on load
	start_new_round()

# --- Round Initialization ---

func start_new_round():
	# 1. Reset data models
	player_hand.clear()
	dealer_hand.clear()
	
	# 2. Clear old card UI nodes from hand containers
	_clear_ui()
	
	# 3. Reset UI status and button states
	status_label.text = "Player's Turn"
	_set_button_states(true)
	
	# 4. Set state & deal initial cards
	current_state = GameState.PLAYER_TURN
	deal_to_player()
	deal_to_dealer(true)  # Hidden card
	deal_to_player()
	deal_to_dealer(false)
	_update_score_labels(false)

# --- Game Actions ---

func player_hit():
	if current_state == GameState.PLAYER_TURN:
		deal_to_player()

func player_stand():
	if current_state == GameState.PLAYER_TURN:
		current_state = GameState.DEALER_TURN
		run_dealer_turn()

func run_dealer_turn():
	# Reveal face-down card and hit dealer if under 17
	while DeckManager.calculate_hand_score(dealer_hand) < 17:
		deal_to_dealer(false)
		
	var player_score = DeckManager.calculate_hand_score(player_hand)
	var dealer_score = DeckManager.calculate_hand_score(dealer_hand)
	
	# Evaluate final scores
	if dealer_score > 21:
		end_game("Dealer Busted! YOU WIN! 🎉")
	elif player_score > dealer_score:
		end_game("YOU WIN! 🏆")
	elif dealer_score > player_score:
		end_game("DEALER WINS! ❌")
	else:
		end_game("PUSH (TIE)! 🤝")

func deal_to_player():
	var card = deck.draw_card()
	player_hand.append(card)
	_instantiate_card_ui(card, player_container)
	_update_score_labels()
	if DeckManager.calculate_hand_score(player_hand) > 21:
		end_game("Player Busted! Dealer Wins.")

func deal_to_dealer(face_down: bool):
	var card = deck.draw_card()
	dealer_hand.append(card)
	
	_instantiate_card_ui(card, dealer_container, face_down)

# --- Helper Methods ---
func _update_score_labels(show_dealer_full: bool = false):
	if player_score_label:
		player_score_label.text = "Player: " + str(DeckManager.calculate_hand_score(player_hand))
	
	if dealer_score_label:
		if show_dealer_full:
			dealer_score_label.text = "Dealer: " + str(DeckManager.calculate_hand_score(dealer_hand))
		else:
			# Hide second card score while player is taking their turn
			dealer_score_label.text = "Dealer: ?"

func _instantiate_card_ui(data: CardData, container: Container, face_down: bool = false):
	var card_scene = preload("res://CardUI.tscn").instantiate()
	container.add_child(card_scene)
	card_scene.set_card(data, face_down)

func _clear_ui():
	# Safely remove all existing card nodes from UI containers
	for child in player_container.get_children():
		child.queue_free()
	for child in dealer_container.get_children():
		child.queue_free()

func _set_button_states(in_progress: bool):
	hit_button.disabled = !in_progress
	stand_button.disabled = !in_progress
	
	if in_progress:
		restart_button.hide()
	else:
		restart_button.show()

func end_game(message: String):
	current_state = GameState.GAME_OVER
	status_label.text = message
	
	_update_score_labels(true)
	_set_button_states(false)
