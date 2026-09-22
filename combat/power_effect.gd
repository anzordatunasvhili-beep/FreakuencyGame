class_name PowerEffect
extends Node2D

@export var effect_shader: Shader
@export var primary_color := Color.WHITE
@export var secondary_color := Color.CYAN
@export_range(4, 256) var particle_amount := 48
@export_range(0.1, 3.0) var duration := 0.65
@export_range(4.0, 300.0) var particle_speed := 80.0
@export_range(8.0, 200.0) var visual_size := 72.0
@export var directional := false

var _elapsed := 0.0
var _visual: Sprite2D

func setup(_ability: AbilityDefinition, direction: Vector2) -> void:
	if directional:
		rotation = direction.angle()
	_build_shader_visual()
	_build_particles()

func _process(delta: float) -> void:
	_elapsed += delta
	if _visual and _visual.material:
		(_visual.material as ShaderMaterial).set_shader_parameter("progress", clampf(_elapsed / duration, 0.0, 1.0))
	if _elapsed >= duration:
		queue_free()

func _build_shader_visual() -> void:
	_visual = Sprite2D.new()
	_visual.texture = _white_texture()
	_visual.scale = Vector2.ONE * (visual_size / 2.0)
	var material := ShaderMaterial.new()
	material.shader = effect_shader
	material.set_shader_parameter("primary_color", primary_color)
	material.set_shader_parameter("secondary_color", secondary_color)
	material.set_shader_parameter("progress", 0.0)
	_visual.material = material
	add_child(_visual)

func _build_particles() -> void:
	var particles := GPUParticles2D.new()
	particles.amount = particle_amount
	particles.lifetime = duration * 0.9
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.texture = _white_texture()
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = visual_size * 0.12
	particle_material.direction = Vector3(1.0, 0.0, 0.0) if directional else Vector3.ZERO
	particle_material.spread = 38.0 if directional else 180.0
	particle_material.initial_velocity_min = particle_speed * 0.55
	particle_material.initial_velocity_max = particle_speed
	particle_material.scale_min = 0.7
	particle_material.scale_max = 1.8
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([primary_color, secondary_color, Color(secondary_color, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	particle_material.color_ramp = ramp
	particles.process_material = particle_material
	add_child(particles)
	particles.emitting = true

func _white_texture() -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

