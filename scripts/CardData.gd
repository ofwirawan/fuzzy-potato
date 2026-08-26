class_name CardData
extends Resource

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES }

@export var suit: Suit
@export var rank: int # 1 = Ace, 11 = Jack, 12 = Queen, 13 = King
@export var texture: Texture2D

func get_value() -> int:
	if rank > 10:
		return 10 # Face cards equal 10
	return rank # Ace defaults to 1, calculated dynamically during scoring
