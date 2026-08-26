class_name CardUI
extends Control

@onready var texture_rect: TextureRect = $TextureRect
@onready var value_label: Label = $ValueLabel

func set_card(data: CardData, face_down: bool = false):
	if face_down:
		# texture_rect.texture = preload("res://assets/card_back.png")
		value_label.text = "" # Hide label when card is face down
	else:
		if data.texture:
			texture_rect.texture = data.texture
			value_label.text = "" # If you have full custom card art, hide the text overlay
		else:
			# Placeholder mode: generate text label automatically (e.g., "A ♥", "10 ♠")
			value_label.text = _get_card_label_text(data)

func _get_card_label_text(data: CardData) -> String:
	var rank_str = ""
	match data.rank:
		1: rank_str = "A"
		11: rank_str = "J"
		12: rank_str = "Q"
		13: rank_str = "K"
		_: rank_str = str(data.rank)
		
	var suit_str = ""
	match data.suit:
		CardData.Suit.HEARTS: suit_str = "♥"
		CardData.Suit.DIAMONDS: suit_str = "♦"
		CardData.Suit.CLUBS: suit_str = "♣"
		CardData.Suit.SPADES: suit_str = "♠"
		
	return rank_str + "\n" + suit_str
