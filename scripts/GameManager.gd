extends Node

enum GameState { BETTING, PLAYER_TURN, DEALER_TURN, GAME_OVER }
var current_state: GameState = GameState.BETTING

var player_hand: Array[CardData] = []
var dealer_hand: Array[CardData] = []

@onready var deck: DeckManager = $DeckManager
@onready var player_container: HBoxContainer = $UI/PlayerHand
@onready var dealer_container: HBoxContainer = $UI/DealerHand

func start_new_round():
	player_hand.clear()
	dealer_hand.clear()
	_clear_ui()
	
	current_state = GameState.PLAYER_TURN
	
	# Deal Initial Hands
	deal_to_player()
	deal_to_dealer(true) # Hidden card
	deal_to_player()
	deal_to_dealer(false)

func deal_to_player():
	var card = deck.draw_card()
	player_hand.append(card)
	_instantiate_card_ui(card, player_container)
	
	if DeckManager.calculate_hand_score(player_hand) > 21:
		end_game("Player Busted! Dealer Wins.")

func player_hit():
	if current_state == GameState.PLAYER_TURN:
		deal_to_player()

func player_stand():
	if current_state == GameState.PLAYER_TURN:
		current_state = GameState.DEALER_TURN
		run_dealer_turn()

func run_dealer_turn():
	# Reveal hidden dealer card UI here
	while DeckManager.calculate_hand_score(dealer_hand) < 17:
		deal_to_dealer(false)
		
	var player_score = DeckManager.calculate_hand_score(player_hand)
	var dealer_score = DeckManager.calculate_hand_score(dealer_hand)
	
	if dealer_score > 21 or player_score > dealer_score:
		end_game("Player Wins!")
	elif dealer_score > player_score:
		end_game("Dealer Wins!")
	else:
		end_game("Push (Tie)!")

func deal_to_dealer(face_down: bool):
	var card = deck.draw_card()
	dealer_hand.append(card)
	_instantiate_card_ui(card, dealer_container, face_down)

func _instantiate_card_ui(data: CardData, container: Container, face_down: bool = false):
	var card_scene = preload("res://CardUI.tscn").instantiate()
	container.add_child(card_scene)
	card_scene.set_card(data, face_down)

func _clear_ui():
	for child in player_container.get_children(): child.queue_free()
	for child in dealer_container.get_children(): child.queue_free()

func end_game(message: String):
	current_state = GameState.GAME_OVER
	print(message) # Display in UI Label
