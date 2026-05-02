extends CharacterBody2D

@export var speed = 200

func _physics_process(delta):
	var direction = Vector2.ZERO

	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1

	velocity = direction.normalized() * speed
	move_and_slide()
	
	if Input.is_action_just_pressed("attack"):
		attack()

func attack():
	print("attack!")

	var bodies = $AttackArea.get_overlapping_bodies()
	#print("hit count:", bodies.size())
	var tween = create_tween()
	# 放大（很快）
	tween.tween_property($AnimatedSprite2D, "scale", Vector2(1.2, 1.2), 0.05)

	# 再缩回（稍慢）
	tween.tween_property($AnimatedSprite2D, "scale", Vector2(1, 1), 0.1)


	for b in bodies:
		if b != self:
			print("hit:", b.name)

			if b.has_method("take_damage"):
				b.take_damage(10, global_position)
