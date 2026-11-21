class_name Encounter
extends Node
## Điều phối các đợt quái trong một phòng. Không có hình ảnh: phòng (C hoặc prefab của B) chứa node này.
##
## Luồng: start() -> lock_requested -> spawn đợt 1 -> hết quái thì spawn đợt kế -> hết đợt cuối thì
## unlock_requested rồi encounter_cleared(result) (chỉ phát đúng một lần).
##
## Co-op (host-authoritative): chỉ host chạy Encounter. Client gọi start() sẽ bị bỏ qua.

signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
## C nối với cửa: khóa khi bắt đầu, mở khi dọn xong.
signal lock_requested
signal unlock_requested
## A dùng `result` để trao thưởng. Keys: room_type, waves, enemies_spawned, enemies_killed,
## had_elite, had_boss, duration.
signal encounter_cleared(result: Dictionary)

enum State { IDLE, RUNNING, CLEARED }

@export var waves: Array[WaveData] = []
## Loại phòng, đưa vào result (vd. &"combat", &"elite", &"boss").
@export var room_type: StringName = &"combat"
## Node chứa các Marker2D điểm spawn.
@export var spawn_points: NodePath
## Node nhận quái vừa spawn (mặc định: node cha của Encounter).
@export var spawn_parent: NodePath
## Điểm spawn phải cách mọi người chơi ít nhất chừng này pixel (nếu không có điểm nào đủ xa thì chọn điểm xa nhất).
@export var min_spawn_distance: float = 150.0
## Nghỉ giữa hai đợt (giây).
@export var wave_delay: float = 1.0
@export var auto_start: bool = false
@export var auto_start_delay: float = 0.5
## Group chứa người chơi. Nếu rỗng thì tìm CharacterBody2D thuộc layer Player (2).
@export var player_group: StringName = &"players"

const LAYER_PLAYER := 2

var state: State = State.IDLE
var wave_index: int = -1

var _alive: Dictionary = {}     # instance_id -> enemy đang sống thuộc đợt hiện tại
var _wave_active: bool = false  # đang trong đợt (cho phép kiểm tra "hết quái")
var _spawned: int = 0
var _killed: int = 0
var _had_elite: bool = false
var _had_boss: bool = false
var _started_msec: int = 0
var _players: Array = []


func _ready() -> void:
	if auto_start:
		await get_tree().create_timer(auto_start_delay).timeout
		start()


## Bắt đầu encounter. Gọi lại khi đang chạy hoặc đã xong thì bị bỏ qua (dùng reset() để chạy lại).
func start() -> void:
	if not _is_authority():
		return
	if state != State.IDLE:
		return
	if waves.is_empty():
		push_warning("Encounter '%s' không có đợt nào, bỏ qua." % name)
		return
	state = State.RUNNING
	wave_index = -1
	_spawned = 0
	_killed = 0
	_had_elite = false
	_had_boss = false
	_started_msec = Time.get_ticks_msec()
	lock_requested.emit()
	_next_wave()


## Đưa về IDLE để chạy lại (không xóa quái đang sống). Chỉ dùng khi không chạy.
func reset() -> void:
	if state == State.RUNNING:
		push_warning("Encounter '%s' đang chạy, không reset được." % name)
		return
	state = State.IDLE
	wave_index = -1
	_alive.clear()
	_wave_active = false


func is_running() -> bool:
	return state == State.RUNNING


func alive_count() -> int:
	return _alive.size()


# ---------------------------------------------------------------- Đợt

func _next_wave() -> void:
	if state != State.RUNNING:
		return
	wave_index += 1
	if wave_index >= waves.size():
		_finish()
		return
	var wave := waves[wave_index]
	var delay := (wave_delay if wave_index > 0 else 0.0) + (wave.delay_before if wave != null else 0.0)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if state != State.RUNNING or not is_inside_tree():
			return
	_spawn_wave(wave)


func _spawn_wave(wave: WaveData) -> void:
	_players = _find_players()
	_wave_active = false
	if wave != null:
		for entry in wave.entries:
			if entry == null or entry.scene == null:
				push_warning("Encounter '%s': đợt %d có dòng rỗng, bỏ qua." % [name, wave_index])
				continue
			for i in entry.count:
				_spawn_one(entry)
	_wave_active = true
	wave_started.emit(wave_index, waves.size())
	# Đợt rỗng (hoặc quái chết ngay) thì coi như đã xong, tránh kẹt.
	if _alive.is_empty():
		_on_wave_cleared()


func _spawn_one(entry: WaveEntry) -> void:
	var enemy := entry.scene.instantiate() as Node2D
	if enemy == null:
		push_warning("Encounter '%s': scene không phải Node2D." % name)
		return
	if entry.elite and "is_elite" in enemy:
		enemy.set("is_elite", true)   # phải đặt trước add_child để _ready áp hệ số Elite
	var parent := _get_spawn_parent()
	parent.add_child(enemy)
	enemy.global_position = _pick_spawn_position()
	var id := enemy.get_instance_id()
	_alive[id] = enemy
	_spawned += 1
	if "is_elite" in enemy and enemy.get("is_elite"):
		_had_elite = true
	if enemy.is_in_group("bosses"):
		_had_boss = true
	if enemy.has_signal("died"):
		enemy.connect("died", _on_enemy_died.bind(id))
	# Phòng hờ quái bị xóa mà không phát died (vd. dọn phòng): vẫn không làm kẹt đợt.
	enemy.tree_exited.connect(_on_enemy_gone.bind(id))


func _on_enemy_died(_enemy: Variant, id: int) -> void:
	_remove_enemy(id, true)


func _on_enemy_gone(id: int) -> void:
	_remove_enemy(id, false)


func _remove_enemy(id: int, killed: bool) -> void:
	if not _alive.has(id):
		return   # died rồi tree_exited: chỉ tính một lần
	_alive.erase(id)
	if killed:
		_killed += 1
	if _wave_active and state == State.RUNNING and _alive.is_empty():
		_on_wave_cleared()


func _on_wave_cleared() -> void:
	if not _wave_active:
		return
	_wave_active = false
	wave_cleared.emit(wave_index)
	_next_wave.call_deferred()


func _finish() -> void:
	if state == State.CLEARED:
		return   # không phát encounter_cleared hai lần
	state = State.CLEARED
	unlock_requested.emit()
	encounter_cleared.emit({
		"room_type": room_type,
		"waves": waves.size(),
		"enemies_spawned": _spawned,
		"enemies_killed": _killed,
		"had_elite": _had_elite,
		"had_boss": _had_boss,
		"duration": float(Time.get_ticks_msec() - _started_msec) / 1000.0,
	})


# ---------------------------------------------------------------- Vị trí spawn

func _get_spawn_parent() -> Node:
	if not spawn_parent.is_empty():
		var n := get_node_or_null(spawn_parent)
		if n != null:
			return n
	return get_parent()


func _get_markers() -> Array[Marker2D]:
	var out: Array[Marker2D] = []
	var holder := get_node_or_null(spawn_points) if not spawn_points.is_empty() else null
	if holder == null:
		return out
	for child in holder.get_children():
		if child is Marker2D:
			out.append(child)
	return out


func _pick_spawn_position() -> Vector2:
	var markers := _get_markers()
	if markers.is_empty():
		push_warning("Encounter '%s' không có điểm spawn, dùng vị trí node cha." % name)
		var p := _get_spawn_parent()
		return p.global_position if p is Node2D else Vector2.ZERO
	var far: Array[Marker2D] = []
	var farthest: Marker2D = markers[0]
	var farthest_d := -1.0
	for m in markers:
		var d := _min_distance_to_players(m.global_position)
		if d >= min_spawn_distance:
			far.append(m)
		if d > farthest_d:
			farthest_d = d
			farthest = m
	var chosen: Marker2D = far.pick_random() if not far.is_empty() else farthest
	return chosen.global_position + Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))


func _min_distance_to_players(pos: Vector2) -> float:
	if _players.is_empty():
		return INF
	var best := INF
	for p in _players:
		if is_instance_valid(p):
			best = minf(best, pos.distance_to((p as Node2D).global_position))
	return best


func _find_players() -> Array:
	var out: Array = []
	if player_group != &"":
		out = get_tree().get_nodes_in_group(player_group)
	if out.is_empty():
		for body in get_tree().root.find_children("*", "CharacterBody2D", true, false):
			if (body as CollisionObject2D).collision_layer & LAYER_PLAYER:
				out.append(body)
	return out


func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
