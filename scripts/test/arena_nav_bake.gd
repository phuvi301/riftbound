extends NavigationRegion2D
## Bake navmesh lúc chạy cho arena test: vùng đi được là lòng arena,
## trừ các vật cản (StaticBody2D có RectangleShape2D) trong group "nav_obstacles".

@export var half_size: Vector2 = Vector2(300, 180)
@export var agent_radius: float = 12.0


func _ready() -> void:
	var nav_poly := NavigationPolygon.new()
	nav_poly.agent_radius = agent_radius

	var source := NavigationMeshSourceGeometryData2D.new()
	source.add_traversable_outline(PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	]))

	for obstacle in get_tree().get_nodes_in_group("nav_obstacles"):
		var shape_node := obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node == null or not (shape_node.shape is RectangleShape2D):
			continue
		var half: Vector2 = (shape_node.shape as RectangleShape2D).size * 0.5
		var c: Vector2 = to_local(obstacle.global_position)
		source.add_obstruction_outline(PackedVector2Array([
			c + Vector2(-half.x, -half.y),
			c + Vector2(half.x, -half.y),
			c + Vector2(half.x, half.y),
			c + Vector2(-half.x, half.y),
		]))

	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source)
	navigation_polygon = nav_poly
