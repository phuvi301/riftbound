class_name WeaponData
extends Resource
## Dữ liệu cơ bản cho vũ khí của Explorer (Pistol, Shotgun, Rifle, Burst Rifle).

@export var id: StringName = &"pistol"
@export var display_name: String = "Pistol"
@export var damage: float = 12.0
@export var fire_rate: float = 3.0 ## Số phát mỗi giây
@export var magazine_size: int = 12
@export var reload_time: float = 1.0
@export var projectile_speed: float = 700.0
@export var spread_deg: float = 2.0
@export var pellets: int = 1
@export var burst_count: int = 1
@export var burst_interval: float = 0.08
@export var energy_cost: float = 0.0
@export var automatic: bool = false
@export var sprite_texture: Texture2D
