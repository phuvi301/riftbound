class_name Player
extends CharacterBody2D
## Nhân vật chính Nova (Explorer của Frontier).
## Điều khiển: WASD di chuyển, chuột ngắm, chuột trái bắn, Space dash, R nạp đạn.

signal dash_cooldown_changed(remaining: float, total: float)
signal scrap_changed(new_amount: int)

@export var move_speed: float = 240.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 1.2

@onready var damageable: Damageable = $Damageable
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var weapon_controller: WeaponController = $WeaponPivot/WeaponController
@onready var sprite: Sprite2D = $Sprite2D

var scrap: int = 0
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	damageable.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if damageable.is_dead:
		return

	_update_timers(delta)
	_aim_at_mouse()
	_handle_movement()
	_handle_combat_input()
	move_and_slide()


func _update_timers(delta: float) -> void:
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_is_dashing = false
			sprite.modulate = Color.WHITE

	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)
		dash_cooldown_changed.emit(_dash_cooldown_timer, dash_cooldown)


func _aim_at_mouse() -> void:
	var aim_vec: Vector2 = get_global_mouse_position() - global_position
	if aim_vec.length_squared() > 0.001:
		weapon_pivot.rotation = aim_vec.angle()
		var facing_left: bool = aim_vec.x < 0.0
		sprite.flip_h = facing_left
		weapon_pivot.scale.y = -1.0 if facing_left else 1.0


func _handle_movement() -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if Input.is_action_just_pressed("dash") and not _is_dashing and _dash_cooldown_timer <= 0.0:
		_start_dash(input_dir)
		return

	if _is_dashing:
		velocity = _dash_direction * dash_speed
	else:
		velocity = input_dir * move_speed


func _start_dash(input_dir: Vector2) -> void:
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	_dash_direction = input_dir.normalized() if input_dir.length_squared() > 0.01 else Vector2.RIGHT.rotated(weapon_pivot.rotation)
	damageable.set_temporary_invulnerable(dash_duration)
	sprite.modulate = Color(1.4, 0.7, 1.8, 0.85)
	dash_cooldown_changed.emit(_dash_cooldown_timer, dash_cooldown)


func _handle_combat_input() -> void:
	if Input.is_action_just_pressed("reload"):
		weapon_controller.start_reload()

	var wants_shoot: bool = false
	if weapon_controller.weapon_data != null and weapon_controller.weapon_data.automatic:
		wants_shoot = Input.is_action_pressed("shoot")
	else:
		wants_shoot = Input.is_action_just_pressed("shoot")

	if wants_shoot:
		var aim_dir: Vector2 = (get_global_mouse_position() - weapon_controller.global_position).normalized()
		if aim_dir.length_squared() < 0.001:
			aim_dir = Vector2.RIGHT.rotated(weapon_pivot.rotation)
		weapon_controller.try_shoot(aim_dir)


func add_scrap(amount: int) -> void:
	scrap = maxi(0, scrap + amount)
	scrap_changed.emit(scrap)


func _on_died(_hit_info: Dictionary) -> void:
	velocity = Vector2.ZERO
	sprite.modulate = Color(0.4, 0.4, 0.45, 0.7)
