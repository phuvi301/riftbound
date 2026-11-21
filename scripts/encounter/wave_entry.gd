class_name WaveEntry
extends Resource
## Một dòng trong đợt: spawn `count` quái từ `scene`.

@export var scene: PackedScene
@export_range(1, 50) var count: int = 1
## Bật để quái này là Elite (nhân chỉ số, đổi màu) mà không cần scene Elite riêng.
@export var elite: bool = false
