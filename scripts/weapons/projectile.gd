class_name Projectile
extends Area2D
## Đạn bắn từ vũ khí (Area2D). Tự hủy khi va chạm tường hoặc mục tiêu hợp lệ.

@export var max_lifetime: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var speed: float = 700.0
var damage: float = 12.0
var team: StringName = &"player"
var is_crit: bool = false
var piercing: bool = false
var hit_id: int = 0

var _lifetime_timer: float = 0.0
var _has_hit: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	if hit_id == 0:
		hit_id = get_instance_id()


func setup(pos: Vector2, dir: Vector2, proj_speed: float, proj_damage: float, attacker_team: StringName = &"player") -> void:
	global_position = pos
	direction = dir.normalized()
	rotation = direction.angle()
	speed = proj_speed
	damage = proj_damage
	team = attacker_team


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_lifetime_timer += delta
	if _lifetime_timer >= max_lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _try_damage_node(body):
		return
	# Va chạm tường/vật cản (Layer 1: Environment)
	if body is StaticBody2D or body is TileMapLayer:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	_try_damage_node(area)


func _try_damage_node(target: Node) -> bool:
	if _has_hit and not piercing:
		return false

	var damageable: Damageable = target.get_node_or_null("Damageable") as Damageable
	if damageable == null and target.get_parent() != null:
		damageable = target.get_parent().get_node_or_null("Damageable") as Damageable

	if damageable == null:
		return false

	var hit_info: Dictionary = {
		"amount": damage,
		"team": team,
		"is_crit": is_crit,
		"hit_id": hit_id,
		"knockback": direction * 80.0,
	}

	if damageable.take_damage(hit_info):
		if not piercing:
			_has_hit = true
			queue_free()
		return true

	return false
