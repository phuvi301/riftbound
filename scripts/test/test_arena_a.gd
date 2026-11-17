extends Node2D
## Phòng thử độc lập cho Thành viên A (M1): kiểm tra Nova, Pistol, đạn, va chạm tường và bia bắn.

@onready var player: Player = $Player
@onready var hud: HUDMinimal = $HUDMinimal


func _ready() -> void:
	hud.bind_player(player)
