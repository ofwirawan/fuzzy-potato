class_name DeckManager
extends Node

@export var card_textures: Array[Texture2D] # Assign 52 textures in Inspector
var cards: Array[CardData] = []

func initialize_deck():
	cards.clear()
	var texture_index = 0
	for suit_idx in range(4):
		for rank_val in range(1, 14):
			var card = CardData.new()
			card.suit = suit_idx as CardData.Suit
			card.rank = rank_val
			if texture_index < card_textures.size():
				card.texture = card_textures[texture_index]
			cards.append(card)
			texture_index += 1
	cards.shuffle()

func draw_card() -> CardData:
	if cards.is_empty():
		initialize_deck()
	return cards.pop_back()

static func calculate_hand_score(hand: Array[CardData]) -> int:
	var total = 0
	var aces = 0
	
	for card in hand:
		if card.rank == 1:
			aces += 1
			total += 11
		else:
			total += card.get_value()
			
	while total > 21 and aces > 0:
		total -= 10
		aces -= 1
		
	return total
