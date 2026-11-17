class_name WeaponController
extends Node2D
## Quản lý vũ khí đang trang bị, module, băng đạn, nạp đạn và sinh đạn.

signal ammo_changed(current_ammo: int, max_ammo: int)
signal reload_started(duration: float)
signal reload_finished
signal weapon_changed(weapon_name: String)

@export var weapon_data: WeaponData
@export var projectile_scene: PackedScene
@export var muzzle_point: Marker2D
@export var weapon_sprite: Sprite2D

var modules: Dictionary = {
	ModuleData.SlotType.BARREL: null,
	ModuleData.SlotType.MAGAZINE: null,
	ModuleData.SlotType.CORE: null,
	ModuleData.SlotType.TRIGGER: null,
}

var current_ammo: int = 0
var is_reloading: bool = false

var _fire_cooldown: float = 0.0
var _reload_timer: float = 0.0


func _ready() -> void:
	if weapon_data == null:
		weapon_data = load("res://resources/weapons/pistol.tres") as WeaponData
	if projectile_scene == null:
		projectile_scene = load("res://scenes/weapons/projectile.tscn") as PackedScene
	equip_weapon(weapon_data)


func _process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(0.0, _fire_cooldown - delta)

	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()


func equip_weapon(new_weapon: WeaponData) -> void:
	weapon_data = new_weapon
	if weapon_data == null:
		return
	if weapon_sprite != null and weapon_data.sprite_texture != null:
		weapon_sprite.texture = weapon_data.sprite_texture
	is_reloading = false
	current_ammo = get_effective_magazine_size()
	weapon_changed.emit(weapon_data.display_name)
	ammo_changed.emit(current_ammo, get_effective_magazine_size())


func equip_module(module: ModuleData) -> ModuleData:
	if module == null:
		return null
	var previous: ModuleData = modules.get(module.slot_type, null)
	modules[module.slot_type] = module
	var max_mag: int = get_effective_magazine_size()
	current_ammo = mini(current_ammo, max_mag)
	ammo_changed.emit(current_ammo, max_mag)
	return previous


func try_shoot(aim_direction: Vector2) -> bool:
	if weapon_data == null or projectile_scene == null:
		return false
	if is_reloading or _fire_cooldown > 0.0:
		return false
	if current_ammo <= 0:
		start_reload()
		return false

	_spawn_shot(aim_direction)
	current_ammo -= 1
	_fire_cooldown = 1.0 / maxf(0.1, get_effective_fire_rate())
	ammo_changed.emit(current_ammo, get_effective_magazine_size())

	if current_ammo <= 0:
		start_reload()
	return true


func start_reload() -> void:
	if weapon_data == null or is_reloading:
		return
	var max_mag: int = get_effective_magazine_size()
	if current_ammo >= max_mag:
		return
	is_reloading = true
	_reload_timer = get_effective_reload_time()
	reload_started.emit(_reload_timer)


func _finish_reload() -> void:
	is_reloading = false
	current_ammo = get_effective_magazine_size()
	ammo_changed.emit(current_ammo, current_ammo)
	reload_finished.emit()


func _spawn_shot(aim_direction: Vector2) -> void:
	var spawn_pos: Vector2 = muzzle_point.global_position if muzzle_point != null else global_position
	var spread_rad: float = deg_to_rad(get_effective_spread_deg())
	var pellets: int = weapon_data.pellets
	var dmg: float = get_effective_damage()
	var spd: float = get_effective_projectile_speed()
	var pierce: bool = _has_piercing()

	for i in range(pellets):
		var angle_offset: float = randf_range(-spread_rad * 0.5, spread_rad * 0.5)
		var shot_dir: Vector2 = aim_direction.rotated(angle_offset)
		var proj: Projectile = projectile_scene.instantiate() as Projectile
		get_tree().current_scene.add_child(proj)
		proj.piercing = pierce
		proj.setup(spawn_pos, shot_dir, spd, dmg, &"player")


func get_effective_damage() -> float:
	var base: float = weapon_data.damage
	var mult: float = 1.0
	var flat: float = 0.0
	for mod: ModuleData in modules.values():
		if mod != null:
			mult *= mod.damage_mult
			flat += mod.damage_flat
	return maxf(1.0, base * mult + flat)


func get_effective_fire_rate() -> float:
	var rate: float = weapon_data.fire_rate
	for mod: ModuleData in modules.values():
		if mod != null:
			rate *= mod.fire_rate_mult
	return maxf(0.2, rate)


func get_effective_magazine_size() -> int:
	var mag: int = weapon_data.magazine_size
	for mod: ModuleData in modules.values():
		if mod != null:
			mag += mod.magazine_flat
	return maxi(1, mag)


func get_effective_reload_time() -> float:
	var reload_t: float = weapon_data.reload_time
	for mod: ModuleData in modules.values():
		if mod != null:
			reload_t *= mod.reload_time_mult
	return maxf(0.2, reload_t)


func get_effective_spread_deg() -> float:
	var spread: float = weapon_data.spread_deg
	for mod: ModuleData in modules.values():
		if mod != null:
			spread += mod.spread_flat_deg
	return maxf(0.0, spread)


func get_effective_projectile_speed() -> float:
	var spd: float = weapon_data.projectile_speed
	for mod: ModuleData in modules.values():
		if mod != null:
			spd *= mod.projectile_speed_mult
	return maxf(100.0, spd)


func _has_piercing() -> bool:
	for mod: ModuleData in modules.values():
		if mod != null and mod.piercing:
			return true
	return false
