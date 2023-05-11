extends Node2D
class_name Game


@onready var player = $Player as Player
@onready var bullet_manager = $BulletManager as BulletManager
@onready var respawn_timer = $RespawnTimer as Timer
@onready var camera = $Camera as ShakeableCamera
@onready var focus_point = $FocusPoint as Node2D
@onready var hud = $HUD as HUD
@onready var pause_menu = $PauseMenu
@onready var game_over = $GameOver as GameOver
@onready var stage_clear = $StageClear as StageClear
@onready var explosion_scene = load("res://scenes/explosion/explosion.tscn") as PackedScene
@onready var points_pickup_scene = load("res://scenes/pickups/points_pickup.tscn") as PackedScene

var score = 0
var lives = 1

var current_level = 0
var levels = [
	"level_1",
	"boss_level",
]
var level: Level = null
var level_size = Vector2.ZERO
var level_exit_reached = false

var is_level_complete = false
var is_game_over = false


func _ready():
	start_game()


func _input(event) -> void:
	if event.is_action_pressed("pause") and not get_tree().paused:
		get_tree().paused = true
		pause_menu.popup_centered()

	if is_game_over and event.is_action_pressed("ui_accept"):
		Globals.main_menu()
	
	if is_level_complete and event.is_action_pressed("ui_accept"):
		call_deferred("load_level", current_level + 1)
		stage_clear.remove()
		stage_clear.hide()


func _process(delta):
	var level_end_position = -level_size.y + Globals.visible_viewport.size.y
	focus_point.position += Vector2.UP * Globals.scroll_speed * delta
	focus_point.position.y = clamp(focus_point.position.y, -level_size.y + Globals.visible_viewport.size.y, 0)
	Globals.visible_viewport.position.y = focus_point.position.y
	
	if focus_point.position.y <= level_end_position:
		Globals.scroll_speed = 0


func _on_shots_fired(shots):
	bullet_manager.spawn_bullets(shots)


func _on_enemy_hurt(enemy: Enemy):
	_add_points_pickups(enemy, "hurt")


func _on_enemy_died(enemy: Enemy):
	_add_points_pickups(enemy, "died")
	_add_pickup(enemy)
	_add_explosion(enemy.position)

	camera.add_trauma(5)
	score += enemy.score
	hud.set_score(score)
	
	check_level_done()
 

func _on_player_hurt():
	camera.add_trauma(1)
	hud.set_health(player.health)


func _on_player_died():
	_add_explosion(player.position)

	call_deferred("remove_child", player)

	camera.add_trauma(5)
	lives -= 1
	hud.disable_bars()
	hud.set_lives(lives)

	if lives <= 0:
		trigger_game_over(false)
	else:
		respawn_timer.start()


func _on_respawn_timer_timeout():
	respawn_player()


func _on_player_healed():
	hud.set_health(player.health)


func _on_player_scored(amount):
	score += amount
	hud.set_score(score)


func _on_player_drone_died(drone):
	_add_explosion(drone.position)
	camera.add_trauma(1)


func _on_level_player_reached_exit():
	print("Level exit reached")
	level_exit_reached = true
	check_level_done()


func _on_pause_menu_exit_game():
	get_tree().paused = false
	Globals.main_menu()


func _on_pause_menu_resume_game():
	get_tree().paused = false
	pause_menu.hide()


func _add_explosion(pos: Vector2) -> void:
	var explosion = explosion_scene.instantiate()
	explosion.position = pos
	add_child(explosion)


func _add_pickup(enemy: Enemy) -> void:
	var pickup_scene = enemy.get_pickup()
	if pickup_scene:
		var pickup = pickup_scene.instantiate()
		pickup.position = enemy.position + Vector2(randf_range(-10, +10), randf_range(-10, +10))
		call_deferred("add_child", pickup)


func _add_points_pickups(enemy: Enemy, source: String) -> void:
	var amount = enemy.get_score_pickups(source)
	var spread = 16
	if source == "died":
		spread = 64

	for x in range(amount):
		var pickup = points_pickup_scene.instantiate()
		pickup.position = Vector2(
			enemy.position.x + randi_range(-spread, spread), 
			enemy.position.y + randi_range(-spread, spread)
		)
		call_deferred("add_child", pickup)


func start_game() -> void:
	load_level()
	sync_hud()


func load_level(index = 0) -> void:
	if index > levels.size() - 1:
		# end screen
		trigger_game_over(true)
		return
	
	var level_scene = levels[index]
	var next_level_resource = load("res://scenes/level/" + level_scene + ".tscn") as PackedScene
	if not next_level_resource:
		return
		
	print("Loading level: " + level_scene)
	unload_level()
	
	level = next_level_resource.instantiate() as Level
	level.name = "Level"
	add_child(level)
	move_child(level, 0)
	
	current_level = index
	
	level_size = level.get_level_size()
	level_exit_reached = false
	is_level_complete = false
	Globals.scroll_speed = level.scroll_speed
	level.player_reached_exit.connect(_on_level_player_reached_exit)
	connect_enemies(level.get_enemies())
	reset_scroll()
	respawn_player(false)

	print("Level size: " + str(level_size))


func unload_level() -> void:
	if has_node("Level"):
		var level = get_node("Level")
		remove_child(level)
		level.call_deferred("free")
	

func connect_enemies(enemies: Array[Enemy]) -> void:
	for enemy in enemies:
		enemy.hurt.connect(_on_enemy_hurt)
		enemy.died.connect(_on_enemy_died)
		enemy.shots_fired.connect(_on_shots_fired)


func reset_scroll() -> void:
	focus_point.position = Vector2.ZERO
	Globals.visible_viewport.position.y = focus_point.position.y


func respawn_player(heal: bool = true) -> void:
	var respawn_position = Vector2(
		Globals.visible_viewport.position.x + Globals.visible_viewport.size.x / 2, 
		Globals.visible_viewport.position.y + Globals.visible_viewport.size.y - 70
	)
	player.respawn(respawn_position, heal)
	hud.set_health(player.health)
	if not get_node("Player"):
		add_child(player)


func sync_hud() -> void:
	hud.set_health(player.health)
	hud.set_score(score)
	hud.set_lives(lives)


func check_level_done() -> void:
	var enemies = level.get_enemies() 
	if level_exit_reached and enemies.size() == 0:
		is_level_complete = true
		
		if current_level < levels.size() - 1:
			stage_clear.show()
			stage_clear.display(score, current_level + 1)
		else:
			call_deferred("load_level", current_level + 1)

func trigger_game_over(won: bool) -> void:
	var is_highscore = score > Globals.high_score
	if is_highscore:
		Globals.high_score = score
		Globals.write_save_game()
	is_game_over = true
	game_over.show()
	game_over.display(score, is_highscore, won)
