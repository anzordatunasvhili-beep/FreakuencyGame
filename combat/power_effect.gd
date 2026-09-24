class_name PowerEffect
extends Node2D
## Presentation for the six original powers. Damage beats live in OriginalPowerRuntime.

const MOTE := preload("res://assets/effects/particles/energy_mote.svg")
const SHARD := preload("res://assets/effects/particles/prism_shard.svg")
const STREAK := preload("res://assets/effects/particles/energy_streak.svg")
const REFRACTION := preload("res://assets/effects/shaders/power_refraction.gdshader")

@export var effect_shader: Shader
@export var primary_color := Color.WHITE
@export var secondary_color := Color.CYAN
@export_range(4, 256) var particle_amount := 48
@export_range(0.1, 3.0) var duration := 1.2
@export_range(4.0, 300.0) var particle_speed := 80.0
@export_range(8.0, 300.0) var visual_size := 150.0
@export var directional := false

var definition: AbilityDefinition
var _elapsed := 0.0
var _beat := 0
var _visual: Sprite2D
var _echo: Sprite2D
var _refraction: ShaderMaterial
var _chain: Line2D
var _orbiters: Array[Sprite2D] = []

func setup(ability: AbilityDefinition, direction: Vector2) -> void:
	definition = ability
	_elapsed = 0.0
	_beat = 0
	z_index = 12
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if directional:
		rotation = direction.angle()
	_build_surfaces()
	_build_orbiters()
	_emit(MOTE, particle_amount / 2, 0.58, visual_size * 0.1, particle_speed * 0.25, false)

func _process(delta: float) -> void:
	if definition == null:
		return
	_elapsed += delta
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	for surface in [_visual, _echo]:
		var shader_material := surface.material as ShaderMaterial
		shader_material.set_shader_parameter("progress", progress)
		shader_material.set_shader_parameter("effect_time", _elapsed)
	_refraction.set_shader_parameter("progress", progress)
	_refraction.set_shader_parameter("effect_time", _elapsed)
	_refraction.set_shader_parameter("strength", sin(progress * PI) * 0.32)
	_animate_secondary(progress)
	_emit_beat()
	if _elapsed >= duration + 0.65:
		queue_free()

func _build_surfaces() -> void:
	var size := Vector2(visual_size, visual_size)
	if directional:
		size = Vector2(visual_size * 1.45, visual_size * 0.78)
	var back_buffer := BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_RECT
	back_buffer.rect = Rect2(-size * 0.6, size * 1.2)
	add_child(back_buffer)
	_refraction = ShaderMaterial.new()
	_refraction.shader = REFRACTION
	_refraction.set_shader_parameter("mode", 1 if directional else 2)
	_refraction.set_shader_parameter("strength", 0.0)
	var refracted := Sprite2D.new()
	refracted.texture = _white_texture()
	refracted.scale = size * 0.5
	refracted.material = _refraction
	add_child(refracted)
	_visual = _make_shader_sprite(size)
	_echo = _make_shader_sprite(size * 1.17)
	_echo.modulate.a = 0.23
	_echo.z_index = -1

func _make_shader_sprite(size: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = _white_texture()
	sprite.scale = size * 0.5
	var material := ShaderMaterial.new()
	material.shader = effect_shader
	material.set_shader_parameter("primary_color", primary_color)
	material.set_shader_parameter("secondary_color", secondary_color)
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("effect_time", 0.0)
	sprite.material = material
	add_child(sprite)
	return sprite

func _animate_secondary(progress: float) -> void:
	_echo.rotation = progress * (0.9 if definition.ability_id == &"glacial_halo" else -0.35)
	if definition.ability_id == &"solar_spear":
		var distance := maxf(0.0, definition.range - definition.effect_distance)
		var step := clampf(_elapsed / 0.53, 0.0, 1.0)
		# The visible spearhead lands at the same point as the projectile hit test.
		_visual.position.x = distance * step - visual_size * 1.45 * 0.5 * 0.62
		_echo.position.x = _visual.position.x
	for i in _orbiters.size():
		var angle := TAU * float(i) / float(_orbiters.size()) + _elapsed * (1.4 if definition.ability_id == &"ember_nova" else -0.6)
		var radius := visual_size * (0.24 + progress * 0.23)
		_orbiters[i].position = Vector2.from_angle(angle) * radius
		_orbiters[i].rotation = angle
		_orbiters[i].modulate.a = sin(progress * PI)
	if is_instance_valid(_chain):
		_chain.modulate.a = 1.0 - smoothstep(0.5, 1.0, progress)

func _emit_beat() -> void:
	var times: Array[float] = []
	match definition.ability_id:
		&"ember_nova": times = [0.12, 0.50, 0.91]
		&"arc_storm": times = [0.10, 0.23, 0.36, 0.49]
		&"void_bloom": times = [0.18, 0.48, 0.82]
		&"glacial_halo": times = [0.18, 0.47, 0.78]
		&"solar_spear": times = [0.10, 0.53]
		&"spirit_pulse": times = [0.10, 0.32]
	while _beat < times.size() and _elapsed >= times[_beat]:
		var radius := 6.0
		var texture: Texture2D = STREAK
		var forward := directional
		match definition.ability_id:
			&"ember_nova": radius = [38.0, 62.0, definition.range][_beat]
			&"arc_storm": radius = 8.0
			&"void_bloom": radius = 20.0 + _beat * 22.0; texture = SHARD
			&"glacial_halo": radius = [38.0, 64.0, definition.range][_beat]; texture = SHARD
			&"solar_spear":
				radius = 5.0 if _beat == 0 else 20.0
				texture = MOTE if _beat == 1 else STREAK
			&"spirit_pulse": radius = 18.0 if _beat == 0 else definition.range * 0.68; texture = MOTE
		var burst := _emit(texture, particle_amount / (3 if _beat > 0 else 2), 0.58, radius, particle_speed * (1.2 if _beat > 0 else 0.7), forward)
		if definition.ability_id == &"solar_spear" and _beat == 1:
			burst.position.x = definition.range - definition.effect_distance
		_beat += 1

func _emit(texture: Texture2D, amount: int, lifetime: float, radius: float, speed: float, forward: bool) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.texture = texture
	particles.visibility_rect = Rect2(-300, -300, 600, 600)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = additive
	var process := ParticleProcessMaterial.new()
	process.particle_flag_disable_z = true
	process.gravity = Vector3.ZERO
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	process.emission_sphere_radius = radius
	process.direction = Vector3.RIGHT
	process.spread = 22.0 if forward else 180.0
	process.initial_velocity_min = speed * 0.45
	process.initial_velocity_max = speed
	process.scale_min = 0.08 if texture == MOTE else 0.12
	process.scale_max = 0.36 if texture == MOTE else 0.32
	process.angle_min = -180.0
	process.angle_max = 180.0
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(secondary_color, 0.0), secondary_color, primary_color, Color(primary_color, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.5, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles

func _build_orbiters() -> void:
	if definition.ability_id not in [&"ember_nova", &"glacial_halo", &"spirit_pulse"]:
		return
	for i in 12:
		var shard := Sprite2D.new()
		shard.texture = MOTE if definition.ability_id == &"spirit_pulse" else SHARD
		shard.scale = Vector2.ONE * 0.21
		shard.modulate = primary_color
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		shard.material = additive
		add_child(shard)
		_orbiters.append(shard)

func show_chain(world_points: PackedVector2Array) -> void:
	if is_instance_valid(_chain):
		_chain.queue_free()
	var local_points := PackedVector2Array()
	for i in world_points.size() - 1:
		var a := to_local(world_points[i])
		var b := to_local(world_points[i + 1])
		var normal := (b - a).orthogonal().normalized()
		if i == 0:
			local_points.append(a)
		for step in 5:
			var f := float(step + 1) / 6.0
			local_points.append(a.lerp(b, f) + normal * sin((step + 1) * 9.7 + _elapsed * 40.0) * 8.0)
		local_points.append(b)
	_chain = Line2D.new()
	_chain.points = local_points
	_chain.width = 6.0
	_chain.default_color = Color(primary_color, 0.65)
	_chain.antialiased = true
	add_child(_chain)
	var core := Line2D.new()
	core.points = local_points
	core.width = 1.8
	core.default_color = Color(0.88, 1.0, 1.0)
	core.antialiased = true
	_chain.add_child(core)

func _white_texture() -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
