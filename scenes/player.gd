extends CharacterBody3D

const SPEED = 1.0

@onready var anim = $Character/AnimationPlayer

var is_attacking = false

func _physics_process(delta):
	var input_dir = Vector3.ZERO

	if Input.is_action_pressed("ui_right"):
		input_dir.x += 1
	if Input.is_action_pressed("ui_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("ui_down"):
		input_dir.z += 1
	if Input.is_action_pressed("ui_up"):
		input_dir.z -= 1

	input_dir = input_dir.normalized()

	# 移动
	if is_attacking:
		velocity.x = 0
		velocity.z = 0
	else:
		velocity.x = input_dir.x * SPEED
		velocity.z = input_dir.z * SPEED
	velocity.y = 0
	move_and_slide()

	# 攻击优先
	if Input.is_action_just_pressed("ui_accept") and not is_attacking:
		play_attack()
		return

	# 攻击中锁定
	if is_attacking:
		return

	# 移动 + 朝向 + 动画
	if input_dir.length() > 0:
		var target_angle = atan2(input_dir.x, input_dir.z)
		$Character.rotation.y = lerp_angle($Character.rotation.y, target_angle, 10 * delta)
		play_anim("walk")
	else:
		play_anim("idle")


func play_anim(name):
	if anim.current_animation != name:
		anim.play(name)


func play_attack():
	is_attacking = true
	anim.play("high_spin_attack")
	await anim.animation_finished
	is_attacking = false
