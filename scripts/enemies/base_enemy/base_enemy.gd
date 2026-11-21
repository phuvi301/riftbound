extends CharacterBody2D
class_name BaseEnemy
## Enemy cơ sở: máu (qua Damageable của A) + FSM + đuổi mục tiêu bằng NavigationAgent2D.
## Enemy cụ thể (MeleeDrone, RangerDrone...) kế thừa và ghi đè các hook ở cuối file.

signal died(enemy)
signal health_changed(current_hp, max_hp)
signal state_changed(old_state, new_state)

enum State { IDLE, CHASE, ATTACK, RECOVER, STUNNED, DEAD }

const LAYER_WORLD := 1    # Environment
const LAYER_PLAYER := 2   # Player
const KNOCKBACK_DECAY := 8.0

@export_group("Stats")
@export var max_health: float = 100.0
@export var armor: float = 0.0
@export var move_speed: float = 100.0

@export_group("AI")
## Bán kính phát hiện mục tiêu khi đang IDLE.
@export var detect_range: float = 250.0
## Đang đuổi mà mục tiêu ra xa quá mức này thì bỏ cuộc (lớn hơn detect_range để tránh nhấp nháy).
@export var lose_range: float = 350.0
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 1.0
## Thời gian ở trạng thái ATTACK (đòn đánh diễn ra).
@export var attack_duration: float = 0.3
## Thời gian đứng yên sau đòn đánh.
@export var recover_time: float = 0.4
@export var require_line_of_sight: bool = true
@export var path_update_interval: float = 0.25

@export_group("Combat")
## Sát thương mỗi đòn (chưa nhân hệ số Elite). Dùng qua get_attack_damage().
@export var attack_damage: float = 10.0

@export_group("Elite")
## Elite không phải lớp mới: chỉ là cờ nhân chỉ số + đổi màu.
@export var is_elite: bool = false
@export var elite_health_mult: float = 2.5
@export var elite_damage_mult: float = 1.5
@export var elite_speed_mult: float = 1.15
@export var elite_tint: Color = Color(1.0, 0.72, 0.35)
@export var elite_scale: float = 1.15

var state: State = State.IDLE
var target: Node2D = null
var damageable: Damageable
## AnimatedSprite2D tên "Visual" (nếu scene có). Cần các animation: idle, move, attack, death.
var visual: AnimatedSprite2D

var _state_time: float = 0.0
var _cooldown_left: float = 0.0
var _path_timer: float = 0.0
var _scan_timer: float = 0.0
var _stun_duration: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _detect_shape := CircleShape2D.new()

@onready var nav_agent: NavigationAgent2D = get_node_or_null("NavigationAgent2D")

static var _hit_counter: int = 1


## Mã hit_id mới cho mỗi đòn của enemy (chống hit trùng, theo contract của A).
static func next_hit_id() -> int:
	_hit_counter += 1
	return _hit_counter


func _ready() -> void:
	add_to_group("enemies")
	if is_elite:
		_apply_elite()
	visual = get_node_or_null("Visual") as AnimatedSprite2D
	if visual:
		# Có sprite thật thì ẩn placeholder.
		var placeholder := get_node_or_null("Sprite2D") as CanvasItem
		if placeholder:
			placeholder.visible = false
		_play_anim(&"idle")
	damageable = get_node_or_null("Damageable") as Damageable
	if damageable == null:
		damageable = Damageable.new()
		damageable.name = "Damageable"
		add_child(damageable)
	damageable.max_hp = max_health
	damageable.armor = armor
	damageable.team = &"enemy"
	damageable.current_hp = max_health
	damageable.hp_changed.connect(func(cur, mx): health_changed.emit(cur, mx))
	damageable.hp_changed.connect(func(_cur, _mx): _update_label())
	damageable.damaged.connect(_on_damaged)
	damageable.died.connect(_on_damageable_died)
	_update_label()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_state_time += delta
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_knockback = _knockback.move_toward(Vector2.ZERO, _knockback.length() * KNOCKBACK_DECAY * delta + 1.0)

	velocity = Vector2.ZERO
	match state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack()
		State.RECOVER:
			_process_recover()
		State.STUNNED:
			_process_stunned()

	velocity += _knockback
	move_and_slide()
	_update_visual()


# ---------------------------------------------------------------- Elite / chỉ số

func _apply_elite() -> void:
	max_health *= elite_health_mult
	attack_damage *= elite_damage_mult
	move_speed *= elite_speed_mult
	scale *= elite_scale
	modulate = elite_tint


## Sát thương một đòn của enemy này (đã gồm hệ số Elite).
func get_attack_damage() -> float:
	return attack_damage


## Tạo hit_info đúng contract của A cho một đòn của enemy.
func make_hit_info(amount: float, knockback: Vector2 = Vector2.ZERO, hit_id: int = 0) -> Dictionary:
	return {
		"amount": amount,
		"team": &"enemy",
		"is_crit": false,
		"hit_id": hit_id if hit_id != 0 else next_hit_id(),
		"knockback": knockback,
	}


# ---------------------------------------------------------------- Hình ảnh

func _play_anim(anim: StringName, from_start: bool = false) -> void:
	if visual == null or not visual.sprite_frames or not visual.sprite_frames.has_animation(anim):
		return
	if visual.animation != anim or from_start or not visual.is_playing():
		visual.play(anim)


## Chọn animation theo trạng thái và quay mặt theo hướng mục tiêu / hướng đi.
func _update_visual() -> void:
	if visual == null:
		return
	var face_x := velocity.x
	if target != null and is_instance_valid(target):
		face_x = target.global_position.x - global_position.x
	if absf(face_x) > 1.0:
		visual.flip_h = face_x < 0.0
	if state == State.CHASE:
		_play_anim(&"move" if velocity.length() > 5.0 else &"idle")


# ---------------------------------------------------------------- Trạng thái

func change_state(new_state: State) -> void:
	if new_state == state or state == State.DEAD:
		return
	var old := state
	state = new_state
	_state_time = 0.0
	_path_timer = 0.0
	_update_label()
	match new_state:
		State.IDLE, State.RECOVER, State.STUNNED:
			_play_anim(&"idle")
		State.ATTACK:
			_play_anim(&"attack", true)
	state_changed.emit(old, new_state)
	_on_state_entered(new_state, old)


func _process_idle(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer > 0.0:
		return
	_scan_timer = 0.2
	target = _find_target()
	if target != null:
		change_state(State.CHASE)


func _process_chase(delta: float) -> void:
	if not _is_target_valid(target) or global_position.distance_to(target.global_position) > lose_range:
		target = null
		change_state(State.IDLE)
		return

	var dist := global_position.distance_to(target.global_position)
	if dist <= attack_range:
		if _cooldown_left <= 0.0 and (not require_line_of_sight or _has_line_of_sight(target)):
			change_state(State.ATTACK)
		return   # trong tầm đánh thì đứng yên, chờ cooldown

	_path_timer -= delta
	if _path_timer <= 0.0:
		_path_timer = path_update_interval
		if nav_agent:
			nav_agent.target_position = target.global_position
	velocity = _get_move_direction() * move_speed


func _process_attack() -> void:
	if _state_time >= attack_duration:
		_cooldown_left = attack_cooldown
		change_state(State.RECOVER)


func _process_recover() -> void:
	if _state_time >= recover_time:
		change_state(State.CHASE if _is_target_valid(target) else State.IDLE)


func _process_stunned() -> void:
	if _state_time >= _stun_duration:
		change_state(State.CHASE if _is_target_valid(target) else State.IDLE)


## Làm enemy choáng (dùng cho đòn của Nova, module, hoặc debug).
func stun(duration: float) -> void:
	if state == State.DEAD:
		return
	_stun_duration = duration
	if state == State.STUNNED:
		_state_time = 0.0
	else:
		change_state(State.STUNNED)


# ---------------------------------------------------------------- Mục tiêu

func _is_target_valid(node: Node2D) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var dmg := node.get_node_or_null("Damageable") as Damageable
	return dmg != null and not dmg.is_dead


## Tìm Nova gần nhất trong detect_range (truy vấn vật lý theo layer Player).
func _find_target() -> Node2D:
	_detect_shape.radius = detect_range
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _detect_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = LAYER_PLAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var best: Node2D = null
	var best_dist := INF
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var body := hit.get("collider") as Node2D
		if not _is_target_valid(body):
			continue
		var dmg := body.get_node("Damageable") as Damageable
		if dmg.team == damageable.team:
			continue
		var d := global_position.distance_to(body.global_position)
		if d < best_dist and (not require_line_of_sight or _has_line_of_sight(body)):
			best = body
			best_dist = d
	return best


func _has_line_of_sight(to: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, to.global_position, LAYER_WORLD, [get_rid()])
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# ---------------------------------------------------------------- Di chuyển

func _get_move_direction() -> Vector2:
	if nav_agent and _nav_map_ready():
		var next_pos := nav_agent.get_next_path_position()
		if not nav_agent.is_navigation_finished():
			return global_position.direction_to(next_pos)
	# Không có navmesh (hoặc chưa sync): đi thẳng tới mục tiêu.
	return global_position.direction_to(target.global_position)


func _nav_map_ready() -> bool:
	return NavigationServer2D.map_get_iteration_id(nav_agent.get_navigation_map()) > 0


# ---------------------------------------------------------------- Sát thương / chết

func _on_damaged(_final_amount: float, hit_info: Dictionary) -> void:
	var kb: Vector2 = hit_info.get("knockback", Vector2.ZERO)
	_knockback += kb


## Tiện ích test: gây damage lên enemy qua đúng contract hit_info.
func take_hit(hit_info: Dictionary) -> bool:
	return damageable.take_damage(hit_info)


func is_dead() -> bool:
	return state == State.DEAD


func _on_damageable_died(_hit_info: Dictionary) -> void:
	die()


func die() -> void:
	if state == State.DEAD:
		return
	change_state(State.DEAD)
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	var label := get_node_or_null("HpLabel") as CanvasItem
	if label:
		label.visible = false
	died.emit(self)
	if visual and visual.sprite_frames and visual.sprite_frames.has_animation(&"death"):
		visual.play(&"death")
		await visual.animation_finished
	if is_inside_tree():
		queue_free()


# ---------------------------------------------------------------- Debug

func _update_label() -> void:
	var label := get_node_or_null("HpLabel") as Label
	if label and damageable:
		label.text = "%.0f / %.0f  %s" % [damageable.current_hp, damageable.max_hp, State.keys()[state]]


# ---------------------------------------------------------------- Hook cho lớp con

## Gọi khi vào một trạng thái. Lớp con ghi đè để bật animation, hitbox, telegraph...
## Ví dụ: new_state == State.ATTACK thì gọi _perform_attack().
func _on_state_entered(new_state: State, _old_state: State) -> void:
	if new_state == State.ATTACK:
		_perform_attack()


## Lớp con ghi đè: thực hiện đòn đánh (cận chiến, bắn đạn, lao...). Mặc định không làm gì.
func _perform_attack() -> void:
	pass
