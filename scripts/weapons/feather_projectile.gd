extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 20.0
var lifetime: float = 2.0
var _spent := false

func setup(dir: Vector2, projectile_speed: float, projectile_damage: float) -> void:
	direction = dir.normalized()
	speed = projectile_speed
	damage = projectile_damage
	rotation = direction.angle()

func _ready() -> void:
	body_entered.connect(_hit)
	area_entered.connect(func(area): _hit(area.get_parent()))

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _hit(body: Node2D) -> void:
	if _spent or not body.has_method("take_damage"):
		return
	_spent = true
	body.take_damage(int(damage))
	queue_free()
