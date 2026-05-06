extends CharacterBody2D

const WALK_SPEED := 130.0
const RUN_SPEED := 230.0
const ATTACK_LOCK_TIME := 0.58
const DASH_ATTACK_LOCK_TIME := 0.48
const DASH_ATTACK_SPEED := 430.0
const MAX_HP := 100
const ATTACK_DAMAGE := 28
const DASH_ATTACK_DAMAGE := 36
const ATTACK_FORWARD_RANGE := 104.0
const ATTACK_SIDE_RANGE := 66.0
const HURT_LOCK_TIME := 0.22

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hp_bar: ProgressBar = $HPBar

var facing := Vector2.RIGHT
var action_lock := 0.0
var locked_velocity := Vector2.ZERO
var key_was_down := {}
var hp := MAX_HP
var dead := false
var pending_hit_time := -1.0
var pending_hit_damage := 0


func _ready() -> void:
	add_to_group("player")
	sprite.sprite_frames = _build_sprite_frames()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hp_bar.max_value = MAX_HP
	hp_bar.value = hp
	_play("idle")


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dash_attack_pressed := _consume_press(KEY_K)
	var attack_pressed := _consume_press(KEY_J)

	if action_lock > 0.0:
		action_lock -= delta
		if pending_hit_time >= 0.0:
			pending_hit_time -= delta
			if pending_hit_time <= 0.0:
				_apply_attack_hit(pending_hit_damage)
				pending_hit_time = -1.0
		velocity = locked_velocity
		move_and_slide()
		if action_lock <= 0.0:
			locked_velocity = Vector2.ZERO
			pending_hit_time = -1.0
		return

	var direction := _read_move_direction()
	if direction != Vector2.ZERO:
		facing = direction
		if absf(facing.x) > 0.01:
			sprite.flip_h = facing.x < 0

	if dash_attack_pressed:
		_start_locked_action("dash_attack", DASH_ATTACK_LOCK_TIME, facing * DASH_ATTACK_SPEED, DASH_ATTACK_DAMAGE, 0.16)
	elif attack_pressed:
		_start_locked_action("attack", ATTACK_LOCK_TIME, Vector2.ZERO, ATTACK_DAMAGE, 0.22)

	if action_lock > 0.0:
		move_and_slide()
		return

	var wants_run := _held(KEY_SHIFT)
	var target_speed := RUN_SPEED if wants_run else WALK_SPEED
	velocity = direction * target_speed
	move_and_slide()

	if direction == Vector2.ZERO:
		_play("idle")
	elif wants_run:
		_play("run")
	else:
		_play("walk")


func _start_locked_action(
	anim_name: StringName,
	duration: float,
	locked_motion: Vector2,
	damage: int = 0,
	hit_delay: float = -1.0
) -> void:
	action_lock = duration
	locked_velocity = locked_motion
	velocity = locked_motion
	pending_hit_damage = damage
	pending_hit_time = hit_delay
	_play(anim_name, true)


func _apply_attack_hit(damage: int) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var enemy_node: Node2D = enemy as Node2D
		if enemy_node == null:
			continue
		var to_enemy: Vector2 = enemy_node.global_position - global_position
		if not _is_in_attack_area(to_enemy):
			continue
		enemy.take_damage(damage, global_position)


func _is_in_attack_area(offset: Vector2) -> bool:
	if offset == Vector2.ZERO:
		return true
	var forward := facing.normalized()
	var right := Vector2(-forward.y, forward.x)
	var forward_distance := offset.dot(forward)
	var side_distance := absf(offset.dot(right))
	return forward_distance >= -18.0 and forward_distance <= ATTACK_FORWARD_RANGE and side_distance <= ATTACK_SIDE_RANGE


func take_damage(amount: int, source_position: Vector2 = Vector2.ZERO) -> void:
	if dead:
		return
	hp = maxi(hp - amount, 0)
	hp_bar.value = hp
	if hp <= 0:
		_die()
		return
	var knockback := (global_position - source_position).normalized() * 75.0
	_start_hurt(knockback)


func heal_fraction(fraction: float) -> void:
	if dead:
		return
	var heal_amount := int(round(MAX_HP * fraction))
	hp = mini(hp + heal_amount, MAX_HP)
	hp_bar.value = hp


func _start_hurt(knockback: Vector2) -> void:
	action_lock = HURT_LOCK_TIME
	locked_velocity = knockback
	pending_hit_time = -1.0
	if sprite.sprite_frames.has_animation("hurt"):
		_play("hurt", true)


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	locked_velocity = Vector2.ZERO
	action_lock = 0.0
	pending_hit_time = -1.0
	hp_bar.value = 0
	if sprite.sprite_frames.has_animation("death"):
		_play("death", true)


func _read_move_direction() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("ui_left") or _held(KEY_A):
		direction.x -= 1.0
	if Input.is_action_pressed("ui_right") or _held(KEY_D):
		direction.x += 1.0
	if Input.is_action_pressed("ui_up") or _held(KEY_W):
		direction.y -= 1.0
	if Input.is_action_pressed("ui_down") or _held(KEY_S):
		direction.y += 1.0
	return direction.normalized()


func _held(keycode: Key) -> bool:
	return Input.is_key_pressed(keycode)


func _consume_press(keycode: Key) -> bool:
	var down := Input.is_key_pressed(keycode)
	var was_down := bool(key_was_down.get(keycode, false))
	key_was_down[keycode] = down
	return down and not was_down


func _play(anim_name: StringName, restart: bool = false) -> void:
	if restart or sprite.animation != anim_name:
		sprite.play(anim_name)


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	_add_frames(frames, "idle", "idle", "Warrior_Idle_%d.png", 6, 8.0, true)
	_add_frames(frames, "walk", "Run", "Warrior_Run_%d.png", 8, 7.0, true)
	_add_frames(frames, "run", "Run", "Warrior_Run_%d.png", 8, 12.0, true)
	_add_frames(frames, "attack", "Attack", "Warrior_Attack_%d.png", 12, 18.0, false)
	_add_frames(frames, "dash_attack", "Dash Attack", "Warrior_Dash-Attack_%d.png", 10, 20.0, false)
	_add_frames(frames, "hurt", "HurtnoEffect", "Warrior_hurt_%d.png", 4, 12.0, false)
	_add_frames(frames, "death", "DeathnoEffect", "Warrior_Death_%d.png", 11, 12.0, false)

	return frames


func _add_frames(
	frames: SpriteFrames,
	anim_name: StringName,
	folder: String,
	file_pattern: String,
	count: int,
	speed: float,
	loops: bool
) -> void:
	frames.add_animation(anim_name)
	frames.set_animation_speed(anim_name, speed)
	frames.set_animation_loop(anim_name, loops)

	for i in range(1, count + 1):
		var path := "res://sprites/Warrior/Individual Sprite/%s/%s" % [folder, file_pattern % i]
		var texture: Resource = load(path)
		if texture != null:
			frames.add_frame(anim_name, texture)
