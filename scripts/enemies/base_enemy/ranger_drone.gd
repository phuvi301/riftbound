extends BaseEnemy
class_name RangerDrone
## Ranger Drone: giữ khoảng cách với mục tiêu, bắn loạt đạn rồi nghỉ.
## - dist < min_range: lùi ra xa.
## - dist > max_range: tiến lại gần (theo navmesh).
## - trong khoảng giữa: đi ngang (strafe), bắn khi hết cooldown.

@export_group("Ranger")
@export var min_range: float = 130.0
@export var max_range: float = 210.0
@export var burst_count: int = 3
@export var burst_interval: float = 0.15
@export var projectile_scene: PackedScene = preload("res://scenes/enemies/projectiles/enemy_bolt.tscn")
@export var projectile_speed: float = 260.0
@export var strafe_speed_factor: float = 0.6
@export var strafe_flip_time: float = 1.6

var _shots_fired: int = 0
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0


func _ready() -> void:
	super()
	attack_range = max_range + 20.0
	attack_duration = burst_interval * float(burst_count) + 0.15
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0


func _process_chase(delta: float) -> void:
	if not _is_target_valid(target) or global_position.distance_to(target.global_position) > lose_range:
		target = null
		change_state(State.IDLE)
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var dir := to_target / maxf(dist, 0.001)

	# Bắn khi trong tầm, hết cooldown và không bị tường chắn.
	if dist <= attack_range and _cooldown_left <= 0.0 and (not require_line_of_sight or _has_line_of_sight(target)):
		change_state(State.ATTACK)
		return

	if dist < min_range:
		velocity = -dir * move_speed
	elif dist > max_range:
		_path_timer -= delta
		if _path_timer <= 0.0:
			_path_timer = path_update_interval
			if nav_agent:
				nav_agent.target_position = target.global_position
		velocity = _get_move_direction() * move_speed
	else:
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = strafe_flip_time
			_strafe_sign = -_strafe_sign
		velocity = dir.orthogonal() * _strafe_sign * move_speed * strafe_speed_factor


func _perform_attack() -> void:
	_shots_fired = 0


func _process_attack() -> void:
	# Đứng yên khi bắn; bắn viên thứ n tại thời điểm n * burst_interval.
	if target != null and is_instance_valid(target):
		while _shots_fired < burst_count and _state_time >= float(_shots_fired) * burst_interval:
			_fire_at(target.global_position)
			_shots_fired += 1
	super()


func _fire_at(pos: Vector2) -> void:
	if projectile_scene == null:
		return
	var dir := global_position.direction_to(pos)
	var bolt := projectile_scene.instantiate() as Projectile
	# Gắn vào scene đang chạy; nếu chưa có (vd. scene được nhúng) thì gắn cạnh enemy.
	var holder: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	holder.add_child(bolt)
	bolt.setup(global_position + dir * 16.0, dir, projectile_speed, get_attack_damage(), &"enemy")
