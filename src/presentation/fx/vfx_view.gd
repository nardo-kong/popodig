class_name VfxView
extends Node2D

# Phase 11 dig/emergency VFX (docs/art/13_AUDIO_VFX_SPEC.md §6/§8/§9): a single
# Node2D drawing a pooled particle list — no per-particle nodes, hard cap, and
# an accessibility "reduced particles" mode that shrinks every burst. Lives in
# WorldView coordinate space so emitters take local cell-space positions.

const MAX_PARTICLES := 220
const REDUCED_PARTICLE_MULTIPLIER := 0.4

# Material debris colors keyed by CellData.TerrainMaterial value.
const MATERIAL_COLORS: Dictionary = {
	1: Color("76543c"), # SOFT_SOIL
	2: Color("574a42"), # DAMP_CLAY
	3: Color("907158"), # LOOSE_SOIL
	4: Color("555351"), # STONE
	5: Color("66615b"), # FOUNDATION
	6: Color("6d5238"), # ROOT_SOIL
}

var _particles: Array[Dictionary] = []
var _cap := MAX_PARTICLES
var reduced_particles := false


func set_reduced_particles(value: bool) -> void:
	reduced_particles = value
	_cap = int(MAX_PARTICLES * REDUCED_PARTICLE_MULTIPLIER) if value else MAX_PARTICLES


func get_active_count() -> int:
	return _particles.size()


func _process(delta: float) -> void:
	if _particles.is_empty():
		if visible:
			visible = false
		return
	visible = true
	for index: int in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		var life := float(particle.life) - delta
		if life <= 0.0:
			_particles.remove_at(index)
			continue
		particle.life = life
		particle.velocity = Vector2(particle.velocity) * (1.0 - 1.8 * delta)
		particle.velocity = Vector2(particle.velocity) + Vector2(0.0, 42.0 * delta) if bool(particle.gravity) else Vector2(particle.velocity)
		particle.position = Vector2(particle.position) + Vector2(particle.velocity) * delta
		_particles[index] = particle
	queue_redraw()


func _draw() -> void:
	for particle: Dictionary in _particles:
		var life_ratio := float(particle.life) / float(particle.max_life)
		var color: Color = particle.color
		color.a *= life_ratio
		if String(particle.kind) == "chunk":
			draw_rect(Rect2(Vector2(particle.position) - Vector2.ONE * float(particle.size) * 0.5, Vector2.ONE * float(particle.size)), color, true)
		else:
			draw_circle(Vector2(particle.position), float(particle.size) * (0.6 + 0.4 * life_ratio), color)


func _spawn(position: Vector2, velocity: Vector2, size: float, color: Color, life: float, kind: String, gravity: bool) -> void:
	if _particles.size() >= _cap:
		_particles.remove_at(0)
	_particles.append({
		"position": position,
		"velocity": velocity,
		"size": size,
		"color": color,
		"life": life,
		"max_life": life,
		"kind": kind,
		"gravity": gravity,
	})


## Dust puff + a few debris chunks when a cell finishes excavating.
func burst_dig(center: Vector2, material: int) -> void:
	var debris: Color = MATERIAL_COLORS.get(material, Color("76543c"))
	var dust_count := 4 if reduced_particles else 7
	for index: int in range(dust_count):
		var angle := TAU * float(index) / float(dust_count) + randf() * 0.5
		_spawn(center + Vector2(0.0, 2.0), Vector2(cos(angle), sin(angle) * 0.6) * (14.0 + randf() * 10.0), 1.6 + randf() * 1.2, Color("c9b28a", 0.6), 0.4 + randf() * 0.25, "dust", false)
	var chunk_count := 2 if reduced_particles else 4
	for index: int in range(chunk_count):
		_spawn(center, Vector2(randf_range(-26.0, 26.0), randf_range(-46.0, -18.0)), 1.2 + randf() * 1.0, debris, 0.5 + randf() * 0.3, "chunk", true)


## Water burst on reservoir breach: directional spray along the release cell.
func burst_water(center: Vector2, released_units: int) -> void:
	var droplet_count := clampi(4 + int(released_units) / 4, 4, 12)
	if reduced_particles:
		droplet_count = mini(droplet_count, 5)
	for index: int in range(droplet_count):
		var angle := -PI * 0.5 + randf_range(-1.1, 1.1)
		var speed := randf_range(30.0, 70.0)
		_spawn(center, Vector2(cos(angle), sin(angle)) * speed, 1.0 + randf() * 1.2, Color("7fc4d4", 0.85), 0.45 + randf() * 0.3, "dust", true)


## Collapse: dust cloud + heavier debris over the collapsed span.
func burst_collapse(center: Vector2, cell_count: int) -> void:
	var dust_count := clampi(6 + cell_count, 6, 16)
	if reduced_particles:
		dust_count = mini(dust_count, 7)
	for index: int in range(dust_count):
		var offset := Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 2.0))
		_spawn(center + offset, Vector2(randf_range(-10.0, 10.0), randf_range(-26.0, -6.0)), 2.0 + randf() * 2.0, Color("a08b6a", 0.7), 0.6 + randf() * 0.5, "dust", false)
	var chunk_count := 3 if reduced_particles else 6
	for index: int in range(chunk_count):
		_spawn(center + Vector2(randf_range(-10.0, 10.0), -4.0), Vector2(randf_range(-34.0, 34.0), randf_range(-40.0, -12.0)), 1.6 + randf() * 1.4, Color("6d5a41"), 0.6 + randf() * 0.4, "chunk", true)


## Occasional settling crumb from a stability warning ceiling.
func spawn_warning_dust(center: Vector2) -> void:
	_spawn(center + Vector2(randf_range(-5.0, 5.0), -4.0), Vector2(randf_range(-4.0, 4.0), 6.0), 1.0 + randf(), Color("c9b28a", 0.55), 0.55, "dust", true)
