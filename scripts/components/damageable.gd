class_name Damageable
extends Node
## Thành phần nhận sát thương dùng chung giữa Player (A) và Enemy (B).
## Quy ước hit_info:
## { "amount": float, "team": StringName, "is_crit": bool, "hit_id": int, "knockback": Vector2 }

signal damaged(final_amount: float, hit_info: Dictionary)
signal hp_changed(current_hp: float, max_hp: float)
signal died(hit_info: Dictionary)

@export var max_hp: float = 100.0
@export var armor: float = 0.0
@export var team: StringName = &"enemy"
@export var invulnerable_duration: float = 0.0
@export var crit_multiplier: float = 2.0

var current_hp: float
var is_dead: bool = false
var _invuln_timer: float = 0.0
var _recent_hit_ids: Array[int] = []

const MAX_TRACKED_HITS: int = 32


func _ready() -> void:
	current_hp = max_hp


func _process(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(0.0, _invuln_timer - delta)


func set_temporary_invulnerable(duration: float) -> void:
	_invuln_timer = maxf(_invuln_timer, duration)


func take_damage(hit_info: Dictionary) -> bool:
	if is_dead or _invuln_timer > 0.0:
		return false

	var attacker_team: StringName = hit_info.get("team", &"")
	if attacker_team != &"" and attacker_team == team:
		return false

	var hit_id: int = hit_info.get("hit_id", 0)
	if hit_id != 0 and hit_id in _recent_hit_ids:
		return false

	if hit_id != 0:
		_recent_hit_ids.append(hit_id)
		if _recent_hit_ids.size() > MAX_TRACKED_HITS:
			_recent_hit_ids.pop_front()

	var raw_damage: float = float(hit_info.get("amount", 0.0))
	if hit_info.get("is_crit", false):
		raw_damage *= crit_multiplier

	# Công thức GDD mục 3.4: D_taken = max(1, D_raw - Armor)
	var final_damage: float = maxf(1.0, raw_damage - armor)
	current_hp = maxf(0.0, current_hp - final_damage)

	if invulnerable_duration > 0.0:
		_invuln_timer = invulnerable_duration

	damaged.emit(final_damage, hit_info)
	hp_changed.emit(current_hp, max_hp)

	if current_hp <= 0.0:
		is_dead = true
		died.emit(hit_info)

	return true


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_hp = minf(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)


func reset_hp() -> void:
	is_dead = false
	_invuln_timer = 0.0
	_recent_hit_ids.clear()
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)
