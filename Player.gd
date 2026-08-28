class_name Player
extends RefCounted

# --- Player Data ---
var peer_id: int = -1
var name: String = "Player"
var hand: Array[CardData] = []

# --- Round States ---
var is_dealer: bool = false
var is_eliminated: bool = false

# --- UI Node References ---
var container: Container = null
var score_label: Label = null


# ==============================================================================
# INITIALIZATION
# ==============================================================================

func _init(p_id: int, p_name: String, p_container: Container = null, p_label: Label = null) -> void:
	peer_id = p_id
	name = p_name
	container = p_container
	score_label = p_label


# ==============================================================================
# HAND & STATE MANAGEMENT
# ==============================================================================

func reset_round() -> void:
	hand.clear()
	is_eliminated = false
	_clear_ui_container()
	update_score_display(-1)


func add_card(card: CardData, face_down: bool = true) -> void:
	if not card: return
	hand.append(card)
	_instantiate_card_ui(card, face_down)


func calculate_score(deck_manager: DeckManager) -> int:
	if not deck_manager: return 0
	return deck_manager.calculate_hand_score(hand)


func is_busted(deck_manager: DeckManager) -> bool:
	return calculate_score(deck_manager) > 21


# ==============================================================================
# VISUAL & UI LOGIC
# ==============================================================================

func reveal_hand() -> void:
	if not container: return
	
	# Iterate over visual card children and reveal card data
	for i in range(hand.size()):
		if i < container.get_child_count():
			var card_ui = container.get_child(i)
			if card_ui and card_ui.has_method("set_card"):
				card_ui.set_card(hand[i], false)


func update_score_display(score: int) -> void:
	if not score_label: return
	
	var role_tag = " (Dealer)" if is_dealer else ""
	
	if is_eliminated:
		score_label.text = name + role_tag + ": ELIMINATED"
	elif score < 0:
		score_label.text = name + role_tag + ": ?"
	else:
		score_label.text = name + role_tag + ": " + str(score)


func _instantiate_card_ui(card: CardData, face_down: bool) -> void:
	if not container: return
	
	var card_scene = preload("res://CardUI.tscn").instantiate()
	container.add_child(card_scene)
	
	if card_scene.has_method("set_card"):
		card_scene.set_card(card, face_down)


func _clear_ui_container() -> void:
	if not container: return
	for child in container.get_children():
		child.queue_free()
