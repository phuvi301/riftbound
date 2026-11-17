class_name ItemData
extends Resource
## Dữ liệu vật phẩm tiêu hao / tài nguyên trong lượt chơi (HP Cell, Shield Cell, Scrap Cache).

enum ItemType {
	HP_CELL,
	SHIELD_CELL,
	SCRAP_CACHE,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var item_type: ItemType = ItemType.HP_CELL
@export var value: float = 25.0
@export var price_scrap: int = 15
