extends CharacterBody2D

@export var max_hp := 60
@export var move_speed := 72.0
@export var attack_damage := 12
@export var detect_range := 360.0
@export var attack_range := 48.0
@export var preferred_distance := 42.0
@export var attack_cooldown := 1.05
@export var display_scale := 3.0
@export var ai_min_think_time := 0.45
@export var ai_max_think_time := 1.1

const ATTACK_LOCK_TIME := 0.58
const ATTACK_HIT_DELAY := 0.28
const HURT_LOCK_TIME := 0.22
const DEATH_CLEANUP_TIME := 1.6
const SEPARATION_DISTANCE := 34.0
const SEPARATION_FORCE := 90.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = $HPBar

var hp := 0
var player: Node2D
var dead := false
var action_lock := 0.0
var attack_timer := 0.0
var pending_attack_hit := false
var pending_attack_time := -1.0
var ai_mode := "approach"
var ai_timer := 0.0
var strafe_sign := 1.0


func _ready() -> void:
	randomize()
	add_to_group("enemy")
	hp = max_hp
	sprite.sprite_frames = _build_sprite_frames()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(display_scale, display_scale)
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	_find_player()
	_play("idle")


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(player):
		_find_player()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	attack_timer = maxf(attack_timer - delta, 0.0)
	ai_timer -= delta

	if action_lock > 0.0:
		action_lock -= delta
		if pending_attack_hit:
			pending_attack_time -= delta
			if pending_attack_time <= 0.0:
				_apply_attack_hit()
				pending_attack_hit = false
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if ai_timer <= 0.0:
		_pick_ai_mode(distance)

	if distance > detect_range:
		velocity = Vector2.ZERO
		_play("idle")
	elif distance <= attack_range and attack_timer <= 0.0:
		_start_attack()
	elif ai_mode == "pause" or distance <= preferred_distance:
		velocity = _separation_velocity(to_player, distance)
		_update_facing(to_player)
		_play("idle")
	else:
		var direction := _movement_direction(to_player, distance)
		velocity = direction * move_speed + _separation_velocity(to_player, distance)
		_update_facing(direction)
		_play("walk")

	move_and_slide()


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	hp = maxi(hp - amount, 0)
	hp_bar.value = hp
	_update_facing(source_position - global_position)
	if hp <= 0:
		_die()
		return
	action_lock = HURT_LOCK_TIME
	pending_attack_hit = false
	velocity = Vector2.ZERO
	_play("hurt", true)


func _start_attack() -> void:
	action_lock = ATTACK_LOCK_TIME
	attack_timer = attack_cooldown
	pending_attack_hit = true
	pending_attack_time = ATTACK_HIT_DELAY
	velocity = Vector2.ZERO
	_update_facing(player.global_position - global_position)
	_play("attack", true)


func _apply_attack_hit() -> void:
	if not is_instance_valid(player) or not player.has_method("take_damage"):
		return
	if global_position.distance_to(player.global_position) <= attack_range + 12.0:
		player.take_damage(attack_damage, global_position)


func _movement_direction(to_player: Vector2, distance: float) -> Vector2:
	var direction := to_player.normalized()
	if ai_mode == "strafe" and distance < detect_range * 0.75:
		var tangent := Vector2(-direction.y, direction.x) * strafe_sign
		return (direction * 0.45 + tangent * 0.85).normalized()
	return direction


func _separation_velocity(to_player: Vector2, distance: float) -> Vector2:
	if distance <= 0.01 or distance >= SEPARATION_DISTANCE:
		return Vector2.ZERO
	var away := -to_player.normalized()
	var strength := 1.0 - distance / SEPARATION_DISTANCE
	return away * SEPARATION_FORCE * strength


func _pick_ai_mode(distance: float) -> void:
	ai_timer = randf_range(ai_min_think_time, ai_max_think_time)
	if distance > detect_range * 0.7:
		ai_mode = "approach"
		return
	var roll := randf()
	if roll < 0.18:
		ai_mode = "pause"
	elif roll < 0.56:
		ai_mode = "strafe"
		strafe_sign = -1.0 if randf() < 0.5 else 1.0
	else:
		ai_mode = "approach"


func _die() -> void:
	dead = true
	remove_from_group("enemy")
	velocity = Vector2.ZERO
	action_lock = 0.0
	pending_attack_hit = false
	hp_bar.visible = false
	_heal_player_on_death()
	_play("death", true)
	await get_tree().create_timer(DEATH_CLEANUP_TIME).timeout
	queue_free()


func _heal_player_on_death() -> void:
	if not is_instance_valid(player):
		_find_player()
	if is_instance_valid(player) and player.has_method("heal_fraction"):
		player.heal_fraction(1.0 / 3.0)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player = players[0] as Node2D


func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > 0.01:
		sprite.flip_h = direction.x > 0


func _play(anim_name: StringName, restart: bool = false) -> void:
	if restart or sprite.animation != anim_name:
		sprite.play(anim_name)


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_frames(frames, "idle", "idle", 4, 6.0, true)
	_add_frames(frames, "walk", "walk", 6, 8.0, true)
	_add_frames(frames, "attack", "attack", 6, 10.0, false)
	_add_frames(frames, "hurt", "hurt", 2, 10.0, false)
	_add_frames(frames, "death", "death", 6, 8.0, false)
	return frames


func _add_frames(frames: SpriteFrames, anim_name: StringName, prefix: String, count: int, speed: float, loops: bool) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	frames.set_animation_loop(anim_name, loops)
	for i in range(count):
		var path := "res://sprites/Enemy/5 Mummy/frames/%s_%02d.png" % [prefix, i]
		var texture: Resource = load(path)
		if texture != null:
			frames.add_frame(anim_name, texture)
