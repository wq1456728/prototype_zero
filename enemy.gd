extends CharacterBody2D

@export var speed: float = 100.0
@onready var hp_bar = $HPBar
@onready var hp_label = $HPBar/Label
var player = null

var hp = 30
var knockback_velocity: Vector2 = Vector2.ZERO


func _ready():
	player = get_tree().get_first_node_in_group("player")
	hp_bar.max_value = hp
	hp_bar.value = hp
	hp_label.text = str(hp) + "/" + str(hp)


func _physics_process(delta):
	if player == null:
		return

	var to_player = player.global_position - global_position
	var distance = to_player.length()

	var direction = Vector2.ZERO

	# 👉 正常追击
	if distance > 80:
		direction = to_player.normalized()

	# 👉 太近 → 强制分离（关键！！）
	elif distance < 75:
		direction = -to_player.normalized()

	# 👉 中间缓冲区（不动）
	else:
		direction = Vector2.ZERO

	var move_velocity = direction * speed

	velocity = move_velocity + knockback_velocity
	move_and_slide()

	knockback_velocity *= 0.6


func take_damage(amount, from_position):
	hp -= amount
	hp_bar.value = hp   # ⭐ 更新血条
	hp_label.text = str(hp) + "/" + str(int(hp_bar.max_value))

	print("enemy hp:", hp)

	var knock_dir = (global_position - from_position).normalized()
	knockback_velocity = knock_dir * 1000

	if hp <= 0:
		die()


func die():
	queue_free()
