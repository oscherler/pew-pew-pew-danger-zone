extends Node2D
class_name BulletEmitter

@export var bullet_scene: PackedScene
@export var homing = false


var bullet_pattern: BulletPattern


func _ready() -> void:
	for child in get_children():
		if child is BulletPattern:
			bullet_pattern = child
			break


func shoot() -> Array:
	if not bullet_pattern:
		return []
	
	var shots = bullet_pattern.generate_shots(owner.position + position)
	if shots:
		for shot in shots:
			shot["scene"] = bullet_scene
			if homing:
				shot["target"] = get_target()
		
		emit_shots(shots)
	
	return shots


func get_target() -> Node2D:
	return null


func emit_shots(shots: Array) -> void:
	pass
