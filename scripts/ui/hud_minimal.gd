class_name HUDMinimal
extends CanvasLayer
## HUD tối thiểu cho M1: HP, Giáp, Vũ khí, Đạn, Nạp đạn, Hồi chiêu Dash và Scrap.

@onready var hp_bar: ProgressBar = $MarginContainer/TopLeft/HPBar
@onready var hp_label: Label = $MarginContainer/TopLeft/HPLabel
@onready var dash_label: Label = $MarginContainer/TopLeft/DashLabel
@onready var scrap_label: Label = $MarginContainer/TopLeft/ScrapLabel
@onready var weapon_label: Label = $MarginContainer/BottomLeft/WeaponLabel
@onready var ammo_label: Label = $MarginContainer/BottomLeft/AmmoLabel

var _player: Player = null


func bind_player(player: Player) -> void:
	_player = player
	if _player == null:
		return

	_player.damageable.hp_changed.connect(_on_hp_changed)
	_player.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
	_player.scrap_changed.connect(_on_scrap_changed)

	var wc: WeaponController = _player.weapon_controller
	wc.ammo_changed.connect(_on_ammo_changed)
	wc.reload_started.connect(_on_reload_started)
	wc.reload_finished.connect(_on_reload_finished)
	wc.weapon_changed.connect(_on_weapon_changed)

	_on_hp_changed(_player.damageable.current_hp, _player.damageable.max_hp)
	_on_dash_cooldown_changed(0.0, _player.dash_cooldown)
	_on_scrap_changed(_player.scrap)
	if wc.weapon_data != null:
		_on_weapon_changed(wc.weapon_data.display_name)
	_on_ammo_changed(wc.current_ammo, wc.get_effective_magazine_size())


func _on_hp_changed(current: float, max_hp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current
	var armor_val: float = _player.damageable.armor if _player != null else 0.0
	hp_label.text = "HP: %.0f / %.0f  |  Giáp: %.0f" % [current, max_hp, armor_val]


func _on_dash_cooldown_changed(remaining: float, _total: float) -> void:
	if remaining <= 0.01:
		dash_label.text = "Dash [Space]: Sẵn sàng"
	else:
		dash_label.text = "Dash [Space]: %.1fs" % remaining


func _on_scrap_changed(new_amount: int) -> void:
	scrap_label.text = "Scrap: %d" % new_amount


func _on_weapon_changed(w_name: String) -> void:
	weapon_label.text = "Vũ khí: %s" % w_name


func _on_ammo_changed(current_ammo: int, max_ammo: int) -> void:
	ammo_label.text = "Đạn: %d / %d" % [current_ammo, max_ammo]


func _on_reload_started(duration: float) -> void:
	ammo_label.text = "Đang nạp đạn (%.1fs)..." % duration


func _on_reload_finished() -> void:
	if _player != null:
		var wc: WeaponController = _player.weapon_controller
		_on_ammo_changed(wc.current_ammo, wc.get_effective_magazine_size())
