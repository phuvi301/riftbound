class_name ModuleData
extends Resource
## Dữ liệu cho 1 module gắn vào vũ khí (Barrel, Magazine, Core, Trigger).

enum SlotType {
	BARREL,
	MAGAZINE,
	CORE,
	TRIGGER,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var slot_type: SlotType = SlotType.BARREL
@export_multiline var description: String = ""

@export_group("Stat Modifiers")
@export var damage_mult: float = 1.0
@export var damage_flat: float = 0.0
@export var fire_rate_mult: float = 1.0
@export var magazine_flat: int = 0
@export var reload_time_mult: float = 1.0
@export var spread_flat_deg: float = 0.0
@export var projectile_speed_mult: float = 1.0
@export var burst_count_add: int = 0

@export_group("Special Effects")
@export var chain_lightning: bool = false
@export var piercing: bool = false
