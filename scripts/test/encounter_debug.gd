extends Node
## Công cụ thử Encounter trong arena.
## F1 hoặc Enter: bắt đầu (hoặc chạy lại). Bảng trạng thái hiện ở góc trái trên màn hình, sự kiện cũng in ra Output.

@export var encounter: NodePath

var _enc: Encounter
var _label: Label
var _last_event: String = ""


func _ready() -> void:
	_enc = get_node_or_null(encounter) as Encounter
	if _enc == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 12)
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)

	_enc.wave_started.connect(func(i, total): _log("Đợt %d/%d bắt đầu" % [i + 1, total]))
	_enc.wave_cleared.connect(func(i): _log("Đợt %d đã dọn" % [i + 1]))
	_enc.lock_requested.connect(func(): _log("KHÓA cửa"))
	_enc.unlock_requested.connect(func(): _log("MỞ cửa"))
	_enc.encounter_cleared.connect(func(r): _log("XONG: %d/%d quái, Elite=%s, Boss=%s, %.1fs" % [r.enemies_killed, r.enemies_spawned, r.had_elite, r.had_boss, r.duration]))
	_refresh()


func _log(text: String) -> void:
	_last_event = text
	print("[Encounter] ", text)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if _label == null or _enc == null:
		return
	var status := ""
	match _enc.state:
		Encounter.State.IDLE:
			status = "Chưa chạy. Nhấn F1 hoặc Enter để bắt đầu."
		Encounter.State.RUNNING:
			status = "ĐANG CHẠY | đợt %d/%d | còn %d quái" % [maxi(_enc.wave_index + 1, 1), _enc.waves.size(), _enc.alive_count()]
		Encounter.State.CLEARED:
			status = "ĐÃ DỌN XONG (cửa mở). Nhấn F1 hoặc Enter để chạy lại."
	_label.text = "Encounter: %s\nSự kiện cuối: %s" % [status, _last_event if _last_event != "" else "-"]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_F1 and event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER:
		return
	if _enc == null:
		return
	if _enc.state == Encounter.State.CLEARED:
		_enc.reset()
	_enc.start()
