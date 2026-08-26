class_name CardUI
extends Control

@onready var texture_rect: TextureRect = $TextureRect
var card_data: CardData

func set_card(data: CardData, face_down: bool = false):
	card_data = data
	if face_down:
		return
		# texture_rect.texture = preload("res://assets/card_back.png")
	else:
		texture_rect.texture = data.texture
