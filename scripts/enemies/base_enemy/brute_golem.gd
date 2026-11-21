extends BaseEnemy
class_name BruteGolem
## Brute Golem: chậm, máu và giáp cao. Đòn lao gồm 3 bước:
## TELEGRAPH (vạch đỏ cảnh báo, khóa hướng) -> DASH (lao thẳng, gây sát thương một lần) -> RECOVER (nghỉ, do FSM).

@export_group("Brute")
@export var telegraph_time: float = 0.7
@export var dash_time: float = 0.35
@export var dash_speed: float = 430.0
@export var hit_knockback: float = 260.0
## Chiều dài và bề rộng vùng cảnh báo (dài bằng quãng lao).
@export var telegraph_width: float = 36.0

var _dash_dir: Vector2 = Vector2.RIGHT
var _attack_hit_id: int = 0
var _has_hit: bool = false
var _telegraph: Polygon2D

@onready var hitbox: Area2D = get_node_or_null("AttackHitbox")


func _ready() -> void:
	super()
	attack_duration = telegraph_time + dash_time
	if hitbox:
		hitbox.monitoring = false
	_telegraph = Polygon2D.new()
	_telegraph.color = Color(0.9, 0.1, 0.15, 0.4)
	_telegraph.visible = false
	_telegraph.z_index = -1
	add_child(_telegraph)


func _perform_attack() -> void:
	_attack_hit_id = BaseEnemy.next_hit_id()
	_has_hit = false
	if target != null and is_instance_valid(target):
		_dash_dir = global_position.direction_to(target.global_position)
	var length := dash_speed * dash_time
	var half := telegraph_width * 0.5
	# Hình chữ nhật dọc theo hướng lao (tọa độ cục bộ; nhân scale ngược để không bị méo khi Elite).
	_telegraph.rotation = _dash_dir.angle()
	_telegraph.polygon = PackedVector2Array([
		Vector2(0, -half), Vector2(length, -half), Vector2(length, half), Vector2(0, half),
	])
	_telegraph.visible = true
	# Giữ khung đầu (cúi người) của animation attack trong lúc cảnh báo.
	if visual:
		visual.frame = 0
		visual.pause()


func _process_attack() -> void:
	if _state_time < telegraph_time:
		# Telegraph: đứng yên, vạch đỏ đậm dần.
		_telegraph.color.a = lerpf(0.2, 0.6, _state_time / telegraph_time)
		return
	if _telegraph.visible:
		_telegraph.visible = false
		if visual:
			visual.play(&"attack")
		if hitbox:
			hitbox.monitoring = true
	velocity = _dash_dir * dash_speed
	_try_hit()
	super()


func _try_hit() -> void:
	if _has_hit or hitbox == null:
		return
	for body in hitbox.get_overlapping_bodies():
		var dmg := body.get_node_or_null("Damageable") as Damageable
		if dmg == null or dmg.team == damageable.team:
			continue
		var info := make_hit_info(get_attack_damage(), _dash_dir * hit_knockback, _attack_hit_id)
		if dmg.take_damage(info):
			_has_hit = true
			return


func _on_state_entered(new_state: State, old_state: State) -> void:
	super(new_state, old_state)
	if new_state != State.ATTACK:
		if _telegraph:
			_telegraph.visible = false
		if hitbox:
			hitbox.set_deferred("monitoring", false)
