class_name WaveData
extends Resource
## Một đợt quái: danh sách {scene, count} cộng thời gian chờ trước khi spawn.

@export var entries: Array[WaveEntry] = []
## Chờ thêm bao lâu (giây) trước khi spawn đợt này, cộng vào `wave_delay` của Encounter.
@export var delay_before: float = 0.0
