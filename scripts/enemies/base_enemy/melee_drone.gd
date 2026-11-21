extends BaseEnemy
class_name MeleeDrone
## Melee Drone: đuổi Nova, lao nhẹ và chém cận chiến.
## Đòn đánh = chuẩn bị (windup) -> cửa sổ trúng đòn (AttackHitbox bật) -> hết đòn.
## Mỗi đòn dùng một hit_id riêng nên chỉ trúng mục tiêu một lần.

@export_group("Melee")
## Thời gian chuẩn bị trước khi hitbox bật (khớp với phần anticipation của animation).
@export var windup_time: float = 0.15
## Thời gian hitbox bật.
@export var active_time: float = 0.12
## Tốc độ lao tới trong cửa sổ trúng đòn.
@export var lunge_speed: float = 220.0
@export var hit_knockback: float = 140.0

var _attack_dir: Vector2 = Vector2.RIGHT
var _attack_hit_id: int = 0
var _has_hit: bool = false

@onready var hitbox: Area2D = get_node_or_null("AttackHitbox")


func _ready() -> void:
	super()
	attack_duration = windup_time + active_time + 0.1
	if hitbox:
		hitbox.monitoring = false


func _perform_attack() -> void:
	_attack_hit_id = BaseEnemy.next_hit_id()
	_has_hit = false
	if target != null and is_instance_valid(target):
		_attack_dir = global_position.direction_to(target.global_position)
	if hitbox:
		hitbox.position = _attack_dir * 18.0
		hitbox.monitoring = false


func _process_attack() -> void:
	var in_window := _state_time >= windup_time and _state_time < windup_time + active_time
	if hitbox:
		hitbox.monitoring = in_window
	if in_window:
		velocity = _attack_dir * lunge_speed
		_try_hit()
	super()


func _try_hit() -> void:
	if _has_hit or hitbox == null:
		return
	for body in hitbox.get_overlapping_bodies():
		var dmg := body.get_node_or_null("Damageable") as Damageable
		if dmg == null or dmg.team == damageable.team:
			continue
		var info := make_hit_info(get_attack_damage(), _attack_dir * hit_knockback, _attack_hit_id)
		if dmg.take_damage(info):
			_has_hit = true
			return


func _on_state_entered(new_state: State, old_state: State) -> void:
	super(new_state, old_state)
	if old_state == State.ATTACK and hitbox:
		hitbox.set_deferred("monitoring", false)
