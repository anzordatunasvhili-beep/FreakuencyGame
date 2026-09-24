class_name SuperpowerEffect
extends Node2D
## Three-stage effects. All geometry is in world units, matching the damage field.

const MOTE := preload("res://assets/effects/particles/energy_mote.svg")
const SHARD := preload("res://assets/effects/particles/prism_shard.svg")
const STREAK := preload("res://assets/effects/particles/energy_streak.svg")
const REFRACTION := preload("res://assets/effects/shaders/power_refraction.gdshader")

@export var effect_shader: Shader
@export var primary_color := Color(0.65, 0.25, 1.0)
@export var secondary_color := Color(1.0, 0.6, 0.9)

var definition: AbilityDefinition
var _elapsed := 0.0
var _duration := 1.0
var _charged := false
var _released := false
var _materials: Array[ShaderMaterial] = []
var _refraction_material: ShaderMaterial
var _orbiters: Array[Sprite2D] = []
var _streams: Array[GPUParticles2D] = []
var _rng := RandomNumberGenerator.new()

func setup(ability: AbilityDefinition, direction: Vector2) -> void:
	definition = ability
	_duration = ability.charge_duration + ability.sustain_duration + ability.release_duration
	_rng.randomize()
	z_index = 12
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if ability.power_kind == &"astral_lance":
		rotation = direction.angle()
	_build_surfaces()
	_build_orbiters()
	_begin_charge()

func _process(delta: float) -> void:
	if definition == null:
		return
	_elapsed += delta
	var charge := clampf(_elapsed / maxf(0.01, definition.charge_duration), 0.0, 1.0)
	var release_start := definition.charge_duration + definition.sustain_duration
	var release := clampf((_elapsed - release_start) / maxf(0.01, definition.release_duration), 0.0, 1.0)
	for shader_material in _materials:
		shader_material.set_shader_parameter("effect_time", _elapsed)
		shader_material.set_shader_parameter("progress", clampf(_elapsed / _duration, 0.0, 1.0))
		shader_material.set_shader_parameter("charge", charge)
		shader_material.set_shader_parameter("release", release)
	_refraction_material.set_shader_parameter("effect_time", _elapsed)
	_refraction_material.set_shader_parameter("progress", clampf(_elapsed / _duration, 0.0, 1.0))
	_refraction_material.set_shader_parameter("strength", charge * (1.0 - release) * 0.6)
	_update_orbiters(charge, release)
	if not _charged and charge >= 1.0:
		_charged = true
		_on_charged()
	if not _released and _elapsed >= release_start:
		_released = true
		for stream in _streams:
			stream.emitting = false
		_on_release()
	if _elapsed >= _duration + 0.9:
		queue_free()

func _build_surfaces() -> void:
	var beam := definition.power_kind == &"astral_lance"
	var surface_size := Vector2(definition.range + 30.0, 110.0) if beam else Vector2.ONE * definition.range * 2.5
	var center := Vector2(definition.range * 0.5, 0.0) if beam else Vector2.ZERO
	# Each overlapping power samples the scene immediately below its own surface.
	var back_buffer := BackBufferCopy.new()
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_RECT
	back_buffer.rect = Rect2(center - surface_size * 0.6, surface_size * 1.2)
	add_child(back_buffer)
	_refraction_material = ShaderMaterial.new()
	_refraction_material.shader = REFRACTION
	_refraction_material.set_shader_parameter("mode", 1 if beam else (2 if definition.power_kind == &"chronostasis" else 0))
	_refraction_material.set_shader_parameter("strength", 0.0)
	_make_surface(surface_size, center, _refraction_material)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = effect_shader
	shader_material.set_shader_parameter("primary_color", primary_color)
	shader_material.set_shader_parameter("secondary_color", secondary_color)
	_make_surface(surface_size, center, shader_material)
	_materials.append(shader_material)

func _make_surface(dimensions: Vector2, center: Vector2, shader_material: ShaderMaterial) -> void:
	var surface := Polygon2D.new()
	var half := dimensions * 0.5
	surface.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
	surface.uv = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	# A one-pixel texture gives Polygon2D normalized UVs independent of world size.
	var gradient := GradientTexture2D.new()
	gradient.width = 1
	gradient.height = 1
	gradient.gradient = Gradient.new()
	gradient.gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	surface.texture = gradient
	surface.position = center
	surface.material = shader_material
	add_child(surface)

func _begin_charge() -> void:
	match definition.power_kind:
		&"event_horizon":
			var dust := _emit(MOTE, 90, 1.1, definition.range * 0.75, -26.0, 12.0, false, 0.16, 0.42)
			var process := dust.process_material as ParticleProcessMaterial
			process.radial_accel_min = -110.0
			process.radial_accel_max = -65.0
			process.tangential_accel_min = 80.0
			process.tangential_accel_max = 125.0
			_streams.append(dust)
		&"astral_lance":
			var charge_sparks := _emit(STREAK, 36, 0.45, 34.0, -80.0, -35.0, true, 0.13, 0.3)
			var process := charge_sparks.process_material as ParticleProcessMaterial
			process.radial_accel_min = -80.0
			process.radial_accel_max = -60.0
		&"chronostasis":
			var frost := _emit(MOTE, 72, 1.5, definition.range * 0.8, 0.0, 7.0, false, 0.1, 0.26)
			_streams.append(frost)
			_emit(SHARD, 20, 0.7, definition.range * 0.7, 8.0, 20.0, true, 0.15, 0.3)

func _on_charged() -> void:
	match definition.power_kind:
		&"event_horizon":
			var accretion := _emit(STREAK, 52, 0.7, definition.range * 0.48, 6.0, 28.0, false, 0.12, 0.26)
			var process := accretion.process_material as ParticleProcessMaterial
			process.tangential_accel_min = -160.0
			process.tangential_accel_max = -120.0
			process.radial_accel_min = -95.0
			process.radial_accel_max = -55.0
			_streams.append(accretion)
		&"astral_lance":
			var beam := _emit(STREAK, 82, 0.42, 5.0, 280.0, 560.0, true, 0.25, 0.65)
			var process := beam.process_material as ParticleProcessMaterial
			process.direction = Vector3.RIGHT
			process.spread = 3.5
			process.particle_flag_align_y = false
			process.angle_min = 0.0
			process.angle_max = 0.0
			var impact := _emit(MOTE, 42, 0.55, 4.0, 30.0, 110.0, true, 0.2, 0.65)
			impact.position.x = definition.range
			_emit(SHARD, 24, 0.65, 8.0, 65.0, 150.0, true, 0.15, 0.32)
		&"chronostasis":
			_emit(STREAK, 48, 0.55, definition.range * 0.85, 2.0, 12.0, true, 0.1, 0.26)

func _on_release() -> void:
	match definition.power_kind:
		&"event_horizon":
			_emit(STREAK, 100, 0.6, 6.0, 100.0, 235.0, true, 0.16, 0.4)
			_emit(MOTE, 52, 0.85, 12.0, 50.0, 160.0, true, 0.18, 0.55)
		&"astral_lance":
			var embers := _emit(MOTE, 32, 0.6, 5.0, 15.0, 40.0, true, 0.12, 0.3)
			var process := embers.process_material as ParticleProcessMaterial
			process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			process.emission_box_extents = Vector3(definition.range * 0.5, 8.0, 0.0)
			embers.position.x = definition.range * 0.5
		&"chronostasis":
			var shards := _emit(SHARD, 88, 0.85, definition.range * 0.65, 35.0, 125.0, true, 0.16, 0.45)
			var process := shards.process_material as ParticleProcessMaterial
			process.angular_velocity_min = -200.0
			process.angular_velocity_max = 200.0
			_emit(MOTE, 52, 0.7, definition.range * 0.7, 35.0, 110.0, true, 0.1, 0.35)

func _emit(texture: Texture2D, count: int, lifetime: float, radius: float, speed_min: float, speed_max: float, burst: bool, scale_min: float, scale_max: float) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.emitting = false
	particles.texture = texture
	particles.amount = count
	particles.lifetime = lifetime
	particles.one_shot = burst
	particles.explosiveness = 1.0 if burst else 0.0
	particles.randomness = 0.35
	particles.local_coords = true
	particles.visibility_rect = Rect2(-400.0, -400.0, 800.0, 800.0)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = additive
	var process := ParticleProcessMaterial.new()
	process.particle_flag_disable_z = true
	process.gravity = Vector3.ZERO
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	process.emission_sphere_radius = radius
	process.direction = Vector3.RIGHT
	process.spread = 180.0
	process.initial_velocity_min = speed_min
	process.initial_velocity_max = speed_max
	process.scale_min = scale_min
	process.scale_max = scale_max
	process.angle_min = -180.0
	process.angle_max = 180.0
	process.damping_min = 8.0
	process.damping_max = 16.0
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(secondary_color, 0.0), secondary_color, primary_color, Color(primary_color, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.1, 0.45, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = curve
	process.scale_curve = scale_curve
	particles.process_material = process
	add_child(particles)
	particles.emitting = true
	if burst:
		particles.finished.connect(particles.queue_free)
	return particles

func _build_orbiters() -> void:
	var count := 8 if definition.power_kind == &"astral_lance" else 18
	for index in count:
		var shard := Sprite2D.new()
		shard.texture = SHARD
		shard.modulate = primary_color.lerp(secondary_color, float(index % 3) * 0.4)
		shard.scale = Vector2.ONE * _rng.randf_range(0.12, 0.3)
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		shard.material = additive
		add_child(shard)
		_orbiters.append(shard)

func _update_orbiters(charge: float, release: float) -> void:
	for index in _orbiters.size():
		var shard := _orbiters[index]
		var phase := TAU * float(index) / float(_orbiters.size())
		var radius := definition.range * (0.55 + float(index % 3) * 0.12)
		match definition.power_kind:
			&"event_horizon":
				phase += _elapsed * (1.3 + float(index % 3) * 0.3)
				radius *= (1.0 - charge * 0.18) * (1.0 - release)
				shard.position = Vector2.from_angle(phase) * radius * Vector2(1.0, 0.65)
				shard.rotation = phase + PI * 0.5
			&"astral_lance":
				phase -= _elapsed * 3.0
				shard.position = Vector2(cos(phase) * 9.0, sin(phase) * (28.0 - charge * 9.0))
				shard.rotation = phase
			&"chronostasis":
				phase += sin(_elapsed * 0.7) * 0.025
				shard.position = Vector2.from_angle(phase) * radius * (1.0 + release * 0.4)
				shard.rotation = phase + _elapsed * 0.08
		shard.modulate.a = charge * (1.0 - release)
