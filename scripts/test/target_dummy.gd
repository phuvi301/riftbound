class_name TargetDummy
extends StaticBody2D
## Bia bắn thử cho Thành viên A kiểm tra vũ khí và sát thương ở M1.

@onready var damageable: Damageable = $Damageable
@onready var visual: Polygon2D = $Visual
@onready var hp_label: Label = $HpLabel

var _flash_timer: float = 0.0
const BASE_COLOR := Color(0.95, 0.45, 0.16, 1.0)
const HIT_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const DEAD_COLOR := Color(0.35, 0.35, 0.4, 0.6)


func _ready() -> void:
	damageable.damaged.connect(_on_damaged)
	damageable.hp_changed.connect(_on_hp_changed)
	damageable.died.connect(_on_died)
	_update_label(damageable.current_hp, damageable.max_hp)


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0 and not damageable.is_dead:
			visual.color = BASE_COLOR


func _on_damaged(final_amount: float, _hit_info: Dictionary) -> void:
	_flash_timer = 0.08
	visual.color = HIT_COLOR
	hp_label.text = "%.0f/%.0f (-%.0f)" % [damageable.current_hp, damageable.max_hp, final_amount]


func _on_hp_changed(current: float, max_hp: float) -> void:
	if not damageable.is_dead:
		_update_label(current, max_hp)


func _on_died(_hit_info: Dictionary) -> void:
	visual.color = DEAD_COLOR
	hp_label.text = "DESTROYED"
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		damageable.reset_hp()
		visual.color = BASE_COLOR


func _update_label(current: float, max_hp: float) -> void:
	hp_label.text = "%.0f / %.0f" % [current, max_hp]
