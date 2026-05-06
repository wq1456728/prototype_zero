extends Node2D

const MUMMY_SCENE := preload("res://scenes/mummy_enemy.tscn")
const RESPAWN_DELAY := 5.0

var respawn_pending := false


func _process(_delta: float) -> void:
	if respawn_pending:
		return
	if get_tree().get_nodes_in_group("enemy").is_empty():
		respawn_pending = true
		await get_tree().create_timer(RESPAWN_DELAY).timeout
		_spawn_wave()
		respawn_pending = false


func _spawn_wave() -> void:
	_spawn_mummy("MummyGrunt", Vector2(500, 300), 55, 68.0, 10, 54.0, 46.0, 1.1, 3.0)
	_spawn_mummy("MummyBrute", Vector2(790, 410), 95, 48.0, 18, 60.0, 52.0, 1.35, 3.35)


func _spawn_mummy(
	enemy_name: String,
	spawn_position: Vector2,
	max_hp: int,
	move_speed: float,
	attack_damage: int,
	attack_range: float,
	preferred_distance: float,
	attack_cooldown: float,
	display_scale: float
) -> void:
	var enemy: Node2D = MUMMY_SCENE.instantiate() as Node2D
	if enemy == null:
		return
	enemy.name = enemy_name
	enemy.position = spawn_position
	enemy.max_hp = max_hp
	enemy.move_speed = move_speed
	enemy.attack_damage = attack_damage
	enemy.attack_range = attack_range
	enemy.preferred_distance = preferred_distance
	enemy.attack_cooldown = attack_cooldown
	enemy.display_scale = display_scale
	add_child(enemy)
