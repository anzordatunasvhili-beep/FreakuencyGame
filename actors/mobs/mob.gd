class_name Mob
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal attack_started(mob: Mob)
signal attack_finished(mob: Mob)
signal died(mob: Mob)

@export var definition: MobDefinition

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var wander_timer: Timer = $WanderTimer
@onready var health_bar: MobHealthBar = $HealthBar

var health := 1
var _home_position := Vector2.ZERO
var _animation_time := 0.0
var _animation_frame := 0
var _action := &""
var _action_locked := false
var _last_direction := Vector2.DOWN
var _rng := RandomNumberGenerator.new()
var _ready_to_move := false
var _combat_target: Node2D = null
var _attack_target: Node = null
var _attack_damage_applied := false
var _attack_cooldown_remaining := 0.0
var _stasis_sources: Dictionary = {}

func _ready() -> void:
	add_to_group("mobs")
	if definition == null or _get_action_texture(&"walk") == null:
		push_error("Mob requires a MobDefinition with a walk or default sprite sheet.")
		set_physics_process(false)
		return

	health = definition.max_health
	health_bar.setup(definition.display_name, health, definition.max_health)
	health_bar.visible = definition.hostile_to_player
	_home_position = global_position
	_rng.seed = int(global_position.x * 92821.0) ^ int(global_position.y * 68917.0) ^ definition.actor_id.hash()
	sprite.region_enabled = true
	sprite.scale = Vector2.ONE * definition.sprite_scale
	sprite.position = definition.sprite_offset
	_configure_collision()
	_set_action(&"idle")
	wander_timer.timeout.connect(_choose_wander_target)
	wander_timer.start(_rng.randf_range(definition.min_idle_time, definition.max_idle_time))
	await get_tree().physics_frame
	_ready_to_move = true

func _physics_process(delta: float) -> void:
	_update_stasis(delta)
	if not _ready_to_move:
		return
	# Impact and death animations always finish, even during a stopped clock.
	if is_in_stasis() and _action != &"hurt" and _action != &"death":
		velocity = Vector2.ZERO
		return
	_attack_cooldown_remaining = maxf(0.0, _attack_cooldown_remaining - delta)
	if _action_locked:
		velocity = Vector2.ZERO
		_update_animation(delta, false)
		return
	if _update_hostile_behavior(delta):
		return
	if navigation_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		_set_action(&"idle")
		_update_animation(delta, false)
		if wander_timer.is_stopped():
			wander_timer.start(_rng.randf_range(definition.min_idle_time, definition.max_idle_time))
		return

	var next_position := navigation_agent.get_next_path_position()
	var direction := global_position.direction_to(next_position)
	velocity = direction * definition.move_speed
	_last_direction = direction
	_set_action(&"walk")
	move_and_slide()
	_update_animation(delta, true)

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(0, health - amount)
	health_bar.set_health(health, definition.max_health)
	health_changed.emit(health, definition.max_health)
	if health == 0:
		_stasis_sources.clear()
		died.emit(self)
		_play_locked_action(&"death")
	else:
		_play_locked_action(&"hurt")

func perform_attack(target: Node = null) -> bool:
	if health <= 0 or is_in_stasis() or _action_locked or definition.attack_sheet == null:
		return false
	_attack_target = target
	_attack_damage_applied = false
	attack_started.emit(self)
	_play_locked_action(&"attack")
	return true

func apply_stasis(source_id: int, duration: float) -> void:
	if health <= 0 or duration <= 0.0:
		return
	_stasis_sources[source_id] = maxf(float(_stasis_sources.get(source_id, 0.0)), duration)
	velocity = Vector2.ZERO

func remove_stasis(source_id: int) -> void:
	_stasis_sources.erase(source_id)

func is_in_stasis() -> bool:
	return health > 0 and not _stasis_sources.is_empty()

func _update_stasis(delta: float) -> void:
	for source_id in _stasis_sources.keys():
		var remaining := float(_stasis_sources[source_id]) - delta
		if remaining <= 0.0:
			_stasis_sources.erase(source_id)
		else:
			_stasis_sources[source_id] = remaining

func apply_gravity_pull(center: Vector2, strength: float, delta: float) -> void:
	if health <= 0 or is_in_stasis():
		return
	var offset := center - global_position
	if offset.length_squared() <= 0.01:
		return
	# CharacterBody movement keeps the pull on the safe side of walls and props.
	move_and_collide(offset.normalized() * minf(offset.length(), maxf(0.0, strength * delta)))

func _play_locked_action(action: StringName) -> void:
	if _get_action_texture(action) == null:
		if action == &"death":
			queue_free()
		return
	_action_locked = true
	_set_action(action, true)

func _finish_locked_action() -> void:
	var finished_action := _action
	_action_locked = false
	if finished_action == &"death":
		queue_free()
		return
	if finished_action == &"attack":
		_attack_target = null
		_attack_cooldown_remaining = definition.attack_cooldown
		attack_finished.emit(self)
	_set_action(&"idle", true)

func _choose_wander_target() -> void:
	if not _ready_to_move or is_in_stasis() or _action_locked or navigation_agent.get_navigation_map().is_valid() == false:
		wander_timer.start(0.5)
		return
	for attempt in 12:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(definition.wander_radius * 0.25, definition.wander_radius)
		var candidate := _home_position + Vector2.from_angle(angle) * distance
		var safe_target := NavigationServer2D.map_get_closest_point(navigation_agent.get_navigation_map(), candidate)
		if safe_target.distance_to(_home_position) <= definition.wander_radius * 1.25 and safe_target.distance_to(global_position) > 4.0:
			navigation_agent.target_position = safe_target
			return
	wander_timer.start(0.5)

func _configure_collision() -> void:
	var shape := CircleShape2D.new()
	shape.radius = definition.collision_radius
	collision_shape.shape = shape

func _set_action(action: StringName, restart := false) -> void:
	if _action == action and not restart:
		return
	_action = action
	_animation_time = 0.0
	_animation_frame = 0
	sprite.texture = _get_action_texture(action)
	_set_sprite_frame(_get_direction_row(), 0)

func _update_animation(delta: float, moving: bool) -> void:
	var frame_count := _get_frame_count(sprite.texture)
	var animate := moving or _action_locked or definition.idle_sheet != null
	if animate:
		_animation_time += delta
		if _animation_time >= 1.0 / definition.animation_fps:
			_animation_time = 0.0
			_animation_frame += 1
			if _action == &"attack" and not _attack_damage_applied and _animation_frame >= maxi(1, frame_count / 2):
				_apply_attack_damage()
			if _action_locked and _animation_frame >= frame_count:
				_finish_locked_action()
				return
			_animation_frame %= frame_count
	else:
		_animation_frame = 0
	_set_sprite_frame(_get_direction_row(), _animation_frame)

func _update_hostile_behavior(delta: float) -> bool:
	if not definition.hostile_to_player:
		return false
	if not is_instance_valid(_combat_target):
		_combat_target = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_combat_target):
		return false

	var distance_to_target := global_position.distance_to(_combat_target.global_position)
	var distance_from_home := global_position.distance_to(_home_position)
	if distance_from_home > definition.chase_leash or distance_to_target > definition.aggro_radius:
		_combat_target = null
		return false

	_last_direction = global_position.direction_to(_combat_target.global_position)
	if distance_to_target <= definition.attack_range:
		velocity = Vector2.ZERO
		_set_action(&"idle")
		_update_animation(delta, false)
		if _attack_cooldown_remaining <= 0.0:
			perform_attack(_combat_target)
		return true

	navigation_agent.target_position = _combat_target.global_position
	if not navigation_agent.is_navigation_finished():
		var next_position := navigation_agent.get_next_path_position()
		var direction := global_position.direction_to(next_position)
		velocity = direction * definition.move_speed
		_last_direction = direction
		_set_action(&"run" if definition.run_sheet else &"walk")
		move_and_slide()
		_update_animation(delta, true)
	return true

func _apply_attack_damage() -> void:
	_attack_damage_applied = true
	if not is_instance_valid(_attack_target):
		return
	if global_position.distance_to((_attack_target as Node2D).global_position) > definition.attack_range * 1.35:
		return
	if _attack_target.has_method("take_damage"):
		_attack_target.take_damage(definition.attack_damage)

func _get_direction_row() -> int:
	if absf(_last_direction.x) > absf(_last_direction.y):
		if definition.use_mirrored_side:
			sprite.flip_h = (_last_direction.x < 0.0) == definition.side_art_faces_right
			return definition.side_row
		sprite.flip_h = false
		return definition.left_row if _last_direction.x < 0.0 else definition.right_row
	sprite.flip_h = false
	return definition.up_row if _last_direction.y < 0.0 else definition.down_row

func _set_sprite_frame(row: int, column: int) -> void:
	if sprite.texture == null:
		return
	var cell_size := _get_cell_size(sprite.texture)
	var row_count := sprite.texture.get_height() / cell_size.y
	var safe_row := clampi(row, 0, row_count - 1)
	var safe_column := clampi(column, 0, _get_frame_count(sprite.texture) - 1)
	sprite.region_rect = Rect2(safe_column * cell_size.x, safe_row * cell_size.y, cell_size.x, cell_size.y)

func _get_cell_size(texture: Texture2D) -> Vector2i:
	if definition.frame_size != Vector2i.ZERO:
		return definition.frame_size
	return Vector2i(
		texture.get_width() / definition.animation_columns,
		texture.get_height() / definition.animation_rows
	)

func _get_frame_count(texture: Texture2D) -> int:
	return maxi(1, texture.get_width() / _get_cell_size(texture).x)

func _get_action_texture(action: StringName) -> Texture2D:
	match action:
		&"idle": return definition.idle_sheet if definition.idle_sheet else definition.sprite_sheet
		&"walk": return definition.walk_sheet if definition.walk_sheet else definition.sprite_sheet
		&"run": return definition.run_sheet if definition.run_sheet else definition.walk_sheet
		&"attack": return definition.attack_sheet
		&"walk_attack": return definition.walk_attack_sheet
		&"run_attack": return definition.run_attack_sheet
		&"hurt": return definition.hurt_sheet
		&"death": return definition.death_sheet
		_: return definition.sprite_sheet
