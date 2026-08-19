class_name RunPowerPropLibrary
extends RefCounted
## Real 3D geometry for every run power, replacing the billboard/particle
## announcement language. Each power owns a distinct code-native prop built from
## primitive meshes, so a trigger reads as the tool or hazard that resolved
## rather than a coloured cloud.
##
## Two gameplay quantities drive the geometry directly:
## - `span` sizes every area prop from the already scaled effective radius;
## - `count` repeats the elements a power counts (orbiting axes, Momentum
##   stacks, Follow-Up repeats, Area Size rings) and the shared destroyed-log
##   tally, so a rank or Area Size change is visible in the mesh itself.
##
## Everything here is presentation. Gameplay has already resolved before a prop
## is built, and no prop reads or writes progression state.

const PROP_SHADER = preload("res://assets/shaders/power_prop.gdshader")
const _STYLE = preload("res://data/painterly_vfx_style_placeholder.tres")

## Hard ceiling on repeated geometry. Authored ladders stay far below this; the
## clamp only stops a pathological count from allocating unbounded meshes.
const MAX_REPEATS := 32

static var _material_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


## Powers whose own identity stat is a count. Their emblem repeats that many
## elements; every other power shows a fixed emblem and lets the shared billet
## tally carry the destroyed-log count.
static func repeats_identity_count(power_id: StringName) -> bool:
	return power_id in [&"whirling_axe", &"momentum", &"follow_up",
		&"area_size", &"double_chop", &"splinter_volley", &"kindling_chain"]


## The literal world radius belongs to the ground ring the burst draws in its
## action silhouette. An emblem is a badge held above the trigger point, so its
## area geometry still grows and shrinks monotonically with the live effective
## radius but inside a bounded envelope, and a large Area Size roll cannot
## swallow the yard behind it.
static func badge_radius(span: float) -> float:
	return clampf(0.062 + 0.038 * maxf(0.0, span), 0.062, 0.20)


## Powers whose emblem is sized by a live effective radius rather than a fixed
## authored envelope.
static func uses_area_span(power_id: StringName) -> bool:
	return power_id in [&"earthshaker", &"powder_keg", &"kindling_chain",
		&"stump_pulse", &"sawblade_halo", &"timber_burst", &"area_size",
		&"ring_reinforcement", &"yard_magnet"]


## Build one power's emblem under `parent` and return every mesh it created.
## `span` is the already Area-Size-scaled effective radius in metres, `count`
## the live identity or payload count. Both are clamped, never re-derived.
static func build_emblem(parent: Node3D, power_id: StringName, color: Color,
		span := 0.0, count := 1) -> Array[MeshInstance3D]:
	var repeats := clampi(count, 1, MAX_REPEATS)
	var base := material_for(color, &"prop")
	var accent := material_for(color.lerp(Color(1.0, 0.94, 0.76, 1.0), 0.55),
		&"accent")
	var steel := material_for(Color(0.62, 0.71, 0.80, 1.0).lerp(color, 0.18),
		&"steel")
	var wood := material_for(Color(0.42, 0.24, 0.11, 1.0).lerp(color, 0.12),
		&"wood")
	var parts: Array[Dictionary] = []
	match power_id:
		&"deep_bite":
			_billet(parts, "BittenLog", wood, Vector3.ZERO, 0.115, 0.20,
				Vector3(0.0, 0.0, PI * 0.5))
			_axe_head(parts, "BiteBlade", steel, wood, Vector3(0.0, 0.075, 0.0),
				1.0, Vector3(0.0, 0.0, -0.42))
			_ring(parts, "BiteRing", accent, Vector3(0.101, 0.0, 0.0), 0.055,
				0.012, Vector3(0.0, 0.0, PI * 0.5))
		&"quick_hands":
			_axe_head(parts, "SwiftBlade", steel, wood, Vector3(0.05, 0.02, 0.0),
				0.92, Vector3(0.0, 0.0, -0.30))
			for index: int in range(3):
				_part(parts, "SpeedBar%d" % (index + 1),
					_box(accent, Vector3(0.11 - float(index) * 0.022, 0.016,
						0.016)),
					Vector3(-0.14, 0.075 - float(index) * 0.055, 0.0))
		&"scar_wisdom":
			_billet(parts, "ScarredRound", wood, Vector3.ZERO, 0.125, 0.075,
				Vector3(PI * 0.5, 0.0, 0.0))
			for index: int in range(2):
				_part(parts, "ScarMark%d" % (index + 1),
					_box(accent, Vector3(0.15, 0.012, 0.018)),
					Vector3(0.0, 0.040, -0.030 + float(index) * 0.060),
					Vector3(0.0, 0.34 - float(index) * 0.68, 0.0))
		&"double_chop":
			for index: int in range(repeats):
				var lean := lerpf(-0.42, 0.42, 0.0 if repeats <= 1 \
					else float(index) / float(repeats - 1))
				_axe_head(parts, "ChopBlade%d" % (index + 1), steel, wood,
					Vector3(sin(lean) * 0.085, 0.02, 0.0), 0.86,
					Vector3(0.0, 0.0, lean))
		&"follow_up":
			for index: int in range(repeats):
				var fade := float(index) / float(maxi(1, repeats))
				_part(parts, "EchoWedge%d" % (index + 1),
					_prism(accent if index == 0 else base,
						Vector3(0.13 - fade * 0.045, 0.15 - fade * 0.05, 0.05)),
					Vector3(-0.055 * float(index), 0.0, -0.05 * float(index)),
					Vector3(0.0, 0.0, PI))
		&"splinter_volley":
			_billet(parts, "VolleyCore", wood, Vector3.ZERO, 0.055, 0.10,
				Vector3(0.0, 0.0, PI * 0.5))
			for index: int in range(repeats):
				var fan := lerpf(-0.95, 0.95, 0.5 if repeats <= 1 \
					else float(index) / float(repeats - 1))
				_part(parts, "Splinter%d" % (index + 1),
					_prism(accent, Vector3(0.028, 0.14, 0.028)),
					Vector3(sin(fan) * 0.10, 0.02 + cos(fan) * 0.055, 0.0),
					Vector3(0.0, 0.0, -fan))
		&"flying_wedge":
			_part(parts, "WedgeBody",
				_prism(steel, Vector3(0.115, 0.26, 0.062)), Vector3.ZERO,
				Vector3(-PI * 0.5, 0.9, 0.0))
			_part(parts, "WedgeFin", _box(accent, Vector3(0.045, 0.10, 0.075)),
				Vector3(0.098, 0.012, 0.082), Vector3(0.0, 0.9, 0.0))
		&"yard_magnet":
			_part(parts, "MagnetArc", _torus(steel, 0.075, 0.115, 12, 24),
				Vector3(0.0, 0.045, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
			for index: int in range(2):
				_part(parts, "MagnetPole%d" % (index + 1),
					_box(accent, Vector3(0.04, 0.075, 0.04)),
					Vector3(-0.095 + float(index) * 0.19, -0.035, 0.0))
			_disc(parts, "PullField", base, badge_radius(span) * 0.95, 0.006,
				Vector3(0.0, -0.085, 0.0))
		&"soft_landing":
			_part(parts, "LandingPad", _box(base, Vector3(0.28, 0.045, 0.18)),
				Vector3(0.0, -0.045, 0.0))
			_billet(parts, "RestingLog", wood, Vector3(0.0, 0.045, 0.0), 0.062,
				0.22, Vector3(0.0, 0.0, PI * 0.5))
			_part(parts, "Cushion", _box(accent, Vector3(0.24, 0.035, 0.15)),
				Vector3(0.0, -0.078, 0.0))
		&"ring_reinforcement":
			var guard := badge_radius(span)
			_part(parts, "GuardRing",
				_torus(steel, guard - 0.022, guard, 10, 28),
				Vector3(0.0, -0.03, 0.0))
			for index: int in range(4):
				var angle := TAU * float(index) / 4.0
				_part(parts, "Buttress%d" % (index + 1),
					_box(wood, Vector3(0.03, 0.10, 0.03)),
					Vector3(cos(angle) * guard, 0.02, sin(angle) * guard))
		&"quick_study":
			for index: int in range(2):
				_part(parts, "Page%d" % (index + 1),
					_box(accent, Vector3(0.13, 0.014, 0.17)),
					Vector3(-0.065 + float(index) * 0.13, 0.0, 0.0),
					Vector3(0.0, 0.0, 0.24 - float(index) * 0.48))
			_part(parts, "Spine", _box(wood, Vector3(0.022, 0.035, 0.175)),
				Vector3(0.0, 0.012, 0.0))
			_part(parts, "Bookmark", _box(base, Vector3(0.02, 0.008, 0.12)),
				Vector3(0.035, 0.028, 0.055))
		&"keen_appraisal":
			for index: int in range(3):
				_part(parts, "Coin%d" % (index + 1),
					_cylinder(accent, 0.062, 0.062, 0.018, 18),
					Vector3(0.0, -0.055 + float(index) * 0.021, 0.0))
			_part(parts, "LensRim", _torus(steel, 0.048, 0.062, 8, 22),
				Vector3(0.055, 0.075, 0.0), Vector3(0.35, 0.0, 0.42))
			_part(parts, "LensGrip", _cylinder(wood, 0.012, 0.012, 0.11, 8),
				Vector3(0.005, 0.010, 0.0), Vector3(0.35, 0.0, 0.42))
		&"area_size":
			for index: int in range(repeats):
				var step := float(index + 1) / float(repeats)
				var radius := badge_radius(span) * step
				_part(parts, "GrowthRing%d" % (index + 1),
					_torus(accent if index == repeats - 1 else base,
						maxf(0.02, radius - 0.014), radius, 8, 26),
					Vector3(0.0, -0.03 + 0.022 * float(index), 0.0))
		&"sawblade_halo":
			var plate := badge_radius(span) * 0.85
			_part(parts, "SawPlate",
				_cylinder(steel, plate, plate, 0.014, 24), Vector3.ZERO)
			for index: int in range(10):
				var angle := TAU * float(index) / 10.0
				_part(parts, "SawTooth%d" % (index + 1),
					_prism(accent, Vector3(0.034, 0.042, 0.014)),
					Vector3(cos(angle) * plate, 0.0, sin(angle) * plate),
					Vector3(0.0, -angle, -PI * 0.5))
			_part(parts, "SawHub", _cylinder(wood, 0.026, 0.026, 0.024, 12),
				Vector3.ZERO)
		&"grain_reader":
			_billet(parts, "GrainRound", wood, Vector3.ZERO, 0.115, 0.05,
				Vector3(PI * 0.5, 0.0, 0.0))
			for index: int in range(3):
				var radius := 0.032 + float(index) * 0.030
				_part(parts, "GrainRing%d" % (index + 1),
					_torus(accent, radius - 0.007, radius, 6, 22),
					Vector3(0.0, 0.0, 0.027), Vector3(PI * 0.5, 0.0, 0.0))
			_part(parts, "ReaderLens", _torus(steel, 0.036, 0.048, 8, 20),
				Vector3(0.065, 0.085, 0.055),
				Vector3(PI * 0.5 - 0.25, 0.0, 0.3))
		&"earthshaker":
			_disc(parts, "ShakerGround", base, badge_radius(span), 0.012,
				Vector3(0.0, -0.05, 0.0))
			for index: int in range(6):
				var angle := TAU * float(index) / 6.0
				var reach := badge_radius(span) * 0.66
				_part(parts, "Upthrust%d" % (index + 1),
					_prism(accent, Vector3(0.042,
						0.11 - 0.012 * float(index % 3), 0.042)),
					Vector3(cos(angle) * reach, -0.02, sin(angle) * reach),
					Vector3(0.0, angle, 0.0))
		&"powder_keg":
			_part(parts, "KegBody", _cylinder(wood, 0.078, 0.078, 0.20, 16),
				Vector3.ZERO)
			for index: int in range(2):
				_part(parts, "KegHoop%d" % (index + 1),
					_torus(steel, 0.078, 0.088, 6, 20),
					Vector3(0.0, -0.055 + float(index) * 0.11, 0.0))
			_part(parts, "KegFuse", _cylinder(accent, 0.008, 0.012, 0.075, 6),
				Vector3(0.022, 0.135, 0.0), Vector3(0.0, 0.0, -0.42))
			_disc(parts, "BlastFloor", base, badge_radius(span), 0.008,
				Vector3(0.0, -0.105, 0.0))
		&"kindling_chain":
			for index: int in range(repeats):
				var offset := (float(index) - float(repeats - 1) * 0.5) * 0.082
				_part(parts, "ChainLink%d" % (index + 1),
					_torus(steel, 0.030, 0.046, 8, 18),
					Vector3(offset, 0.0, 0.0),
					Vector3(PI * 0.5, 0.0, 0.0) if index % 2 == 0 \
						else Vector3.ZERO)
				_part(parts, "Kindling%d" % (index + 1),
					_box(wood, Vector3(0.030, 0.030, 0.10)),
					Vector3(offset, -0.055, 0.0),
					Vector3(0.0, 0.28 * float(index % 3) - 0.28, 0.0))
		&"whirling_axe":
			# The track widens and each tool shrinks as the axe count rises, so
			# a higher rank stays legible as separate axes instead of a knot.
			var track := 0.058 + 0.030 * float(repeats)
			var tool_size := 0.62 * clampf(4.0 / float(repeats), 0.5, 1.0)
			_part(parts, "OrbitTrack",
				_torus(base, track - 0.008, track, 6, 34), Vector3.ZERO)
			for index: int in range(repeats):
				var angle := TAU * float(index) / float(repeats)
				_axe_head(parts, "OrbitAxe%d" % (index + 1), steel, wood,
					Vector3(cos(angle) * track, 0.0, sin(angle) * track),
					tool_size, Vector3(0.0, -angle, -0.38))
		&"crosscut_sweep":
			_part(parts, "SawBlade", _box(steel, Vector3(0.30, 0.055, 0.014)),
				Vector3.ZERO)
			for index: int in range(8):
				_part(parts, "SweepTooth%d" % (index + 1),
					_prism(accent, Vector3(0.030, 0.032, 0.014)),
					Vector3(-0.125 + float(index) * 0.036, -0.042, 0.0),
					Vector3(PI, 0.0, 0.0))
			for index: int in range(2):
				_part(parts, "SweepGrip%d" % (index + 1),
					_cylinder(wood, 0.016, 0.016, 0.070, 8),
					Vector3(-0.175 + float(index) * 0.35, 0.030, 0.0))
		&"maul_drop":
			_part(parts, "MaulBlock", _box(steel, Vector3(0.16, 0.075, 0.085)),
				Vector3(0.0, 0.085, 0.0))
			_part(parts, "MaulEdge",
				_prism(accent, Vector3(0.085, 0.055, 0.085)),
				Vector3(-0.115, 0.085, 0.0), Vector3(0.0, 0.0, PI * 0.5))
			_part(parts, "MaulShaft", _cylinder(wood, 0.014, 0.019, 0.22, 8),
				Vector3(0.0, -0.045, 0.0))
		&"splitter_rig":
			for index: int in range(2):
				_part(parts, "RigRail%d" % (index + 1),
					_box(steel, Vector3(0.022, 0.20, 0.022)),
					Vector3(-0.085 + float(index) * 0.17, 0.0, 0.0))
			_part(parts, "RigBed", _box(wood, Vector3(0.22, 0.028, 0.11)),
				Vector3(0.0, -0.10, 0.0))
			_part(parts, "RigWedge", _prism(accent, Vector3(0.085, 0.10, 0.055)),
				Vector3(0.0, 0.035, 0.0), Vector3(0.0, 0.0, PI))
		&"cant_hook":
			_part(parts, "HookShaft", _cylinder(wood, 0.015, 0.021, 0.26, 8),
				Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.0, 0.30))
			_part(parts, "HookArc", _torus(steel, 0.052, 0.068, 8, 18),
				Vector3(0.062, -0.075, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
			_part(parts, "HookTip", _prism(accent, Vector3(0.030, 0.055, 0.026)),
				Vector3(0.118, -0.052, 0.0), Vector3(0.0, 0.0, -0.9))
		&"stump_pulse":
			_part(parts, "PulseStump",
				_cylinder(wood, 0.092, 0.105, 0.095, 18),
				Vector3(0.0, -0.045, 0.0))
			for index: int in range(3):
				var radius := badge_radius(span) \
					* (0.45 + 0.28 * float(index))
				_part(parts, "PulseRing%d" % (index + 1),
					_torus(accent, maxf(0.02, radius - 0.011), radius, 6, 24),
					Vector3(0.0, 0.010 + 0.030 * float(index), 0.0))
		&"last_ditch_rescue":
			_part(parts, "RescueRing", _torus(accent, 0.070, 0.105, 10, 26),
				Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
			for index: int in range(2):
				_part(parts, "RescueStrap%d" % (index + 1),
					_box(base, Vector3(0.21, 0.016, 0.022)), Vector3.ZERO,
					Vector3(0.0, PI * 0.5 * float(index), 0.0))
			_part(parts, "RescueGrip", _cylinder(wood, 0.020, 0.020, 0.055, 10),
				Vector3(0.0, 0.055, 0.0))
		&"momentum":
			for index: int in range(repeats):
				_part(parts, "MomentumChevron%d" % (index + 1),
					_prism(accent if index == repeats - 1 else base,
						Vector3(0.085 + 0.020 * float(index), 0.048, 0.05)),
					Vector3(0.0, -0.055 + 0.055 * float(index), 0.0))
		&"timber_burst":
			_disc(parts, "BurstFloor", base, badge_radius(span), 0.010,
				Vector3(0.0, -0.055, 0.0))
			for index: int in range(6):
				var angle := TAU * float(index) / 6.0
				var reach := badge_radius(span) * 0.70
				_billet(parts, "BurstBillet%d" % (index + 1), wood,
					Vector3(cos(angle) * reach, 0.015, sin(angle) * reach),
					0.026, 0.095, Vector3(0.0, -angle, PI * 0.5))
		_:
			# Every catalogue id is authored above. A future power still gets
			# readable solid geometry instead of silently falling back to the
			# retired particle language.
			_billet(parts, "GenericBillet", wood, Vector3.ZERO, 0.075, 0.20,
				Vector3(0.0, 0.0, PI * 0.5))
			_ring(parts, "GenericRing", accent, Vector3.ZERO, 0.105, 0.014,
				Vector3(PI * 0.5, 0.0, 0.0))
	return _instantiate(parent, parts)


## The live tools circling the stump use the same axe silhouette as the Whirling
## Axe emblem, so the announcement and the thing actually orbiting are one object.
static func build_orbit_axe(parent: Node3D, color: Color,
		size := 1.0) -> Array[MeshInstance3D]:
	var steel := material_for(Color(0.62, 0.71, 0.80, 1.0).lerp(color, 0.18),
		&"steel")
	var wood := material_for(Color(0.42, 0.24, 0.11, 1.0).lerp(color, 0.12),
		&"wood")
	var parts: Array[Dictionary] = []
	_axe_head(parts, "OrbitAxe", steel, wood, Vector3.ZERO, size, Vector3.ZERO)
	return _instantiate(parent, parts)


## One shared destroyed-log token. The burst spawns exactly the reported number
## of these, so a ×4 receipt puts four real billets on screen.
static func build_tally_billet(parent: Node3D, index: int,
		color: Color) -> MeshInstance3D:
	var wood := material_for(Color(0.46, 0.27, 0.12, 1.0).lerp(color, 0.22),
		&"tally")
	var parts: Array[Dictionary] = []
	_billet(parts, "Billet%d" % (index + 1), wood, Vector3.ZERO, 0.048, 0.17,
		Vector3(0.0, 0.0, PI * 0.5))
	var created := _instantiate(parent, parts)
	return created[0] if not created.is_empty() else null


static func material_for(color: Color, variant: StringName) -> ShaderMaterial:
	var key := "%s|%s" % [color.to_html(true), String(variant)]
	var cached := _material_cache.get(key) as ShaderMaterial
	if cached != null:
		return cached
	var material := ShaderMaterial.new()
	material.shader = PROP_SHADER
	material.set_shader_parameter("dark_color",
		Color(color.r * 0.52, color.g * 0.52, color.b * 0.58, 1.0))
	material.set_shader_parameter("mid_color", color)
	material.set_shader_parameter("light_color", color.lerp(Color.WHITE, 0.58))
	material.set_shader_parameter("opacity", 1.0)
	material.set_shader_parameter("dry_amount", _STYLE.daub_dry_amount)
	material.set_shader_parameter("rim_strength", 0.55)
	material.set_shader_parameter("seed",
		float(absi(String(variant).hash() % 97)) * 0.31)
	_material_cache[key] = material
	return material


static func clear_caches() -> void:
	_material_cache.clear()
	_mesh_cache.clear()


static func _instantiate(parent: Node3D,
		parts: Array[Dictionary]) -> Array[MeshInstance3D]:
	var created: Array[MeshInstance3D] = []
	for part: Dictionary in parts:
		var instance := MeshInstance3D.new()
		instance.name = String(part["name"])
		instance.mesh = part["mesh"] as Mesh
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.transform = part["transform"] as Transform3D
		parent.add_child(instance)
		created.append(instance)
	return created


static func _part(parts: Array[Dictionary], part_name: String,
		mesh: PrimitiveMesh, position: Vector3,
		rotation := Vector3.ZERO) -> void:
	_part_basis(parts, part_name, mesh, position, Basis.from_euler(rotation))


static func _part_basis(parts: Array[Dictionary], part_name: String,
		mesh: PrimitiveMesh, position: Vector3, basis: Basis) -> void:
	parts.append({
		"name": part_name,
		"mesh": mesh,
		"transform": Transform3D(basis, position),
	})


## Shared sub-assemblies. Several powers are the same tool seen in a different
## pose, so these keep one silhouette instead of three drifting copies.
static func _axe_head(parts: Array[Dictionary], part_name: String,
		steel: ShaderMaterial, wood: ShaderMaterial, origin: Vector3,
		size: float, rotation: Vector3) -> void:
	var basis := Basis.from_euler(rotation)
	_part_basis(parts, part_name,
		_prism(steel, Vector3(0.105 * size, 0.115 * size, 0.026 * size)),
		origin + basis * Vector3(0.012 * size, 0.055 * size, 0.0),
		basis * Basis.from_euler(Vector3(0.0, 0.0, PI * 0.5)))
	_part(parts, "%sPoll" % part_name,
		_box(steel, Vector3(0.05 * size, 0.05 * size, 0.032 * size)),
		origin + basis * Vector3(0.055 * size, 0.075 * size, 0.0), rotation)
	_part(parts, "%sHaft" % part_name,
		_cylinder(wood, 0.012 * size, 0.016 * size, 0.20 * size, 8),
		origin + basis * Vector3(0.0, -0.055 * size, 0.0), rotation)


static func _billet(parts: Array[Dictionary], part_name: String,
		material: ShaderMaterial, origin: Vector3, radius: float,
		length: float, rotation: Vector3) -> void:
	_part(parts, part_name, _cylinder(material, radius, radius, length, 12),
		origin, rotation)


static func _ring(parts: Array[Dictionary], part_name: String,
		material: ShaderMaterial, origin: Vector3, radius: float,
		thickness: float, rotation: Vector3) -> void:
	_part(parts, part_name,
		_torus(material, maxf(0.004, radius - thickness), radius, 8, 24),
		origin, rotation)


static func _disc(parts: Array[Dictionary], part_name: String,
		material: ShaderMaterial, radius: float, thickness: float,
		origin: Vector3) -> void:
	_part(parts, part_name,
		_cylinder(material, radius, radius, thickness, 26), origin)


## Primitive factories. Meshes are cached by their exact authored dimensions and
## the material they carry, so repeated bursts reuse one resource per distinct
## shape while two powers can never share and overwrite a pigment.
static func _box(material: ShaderMaterial, size: Vector3) -> BoxMesh:
	var key := "box|%d|%.4f|%.4f|%.4f" % [material.get_instance_id(),
		size.x, size.y, size.z]
	var cached := _mesh_cache.get(key) as BoxMesh
	if cached != null:
		return cached
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	_mesh_cache[key] = mesh
	return mesh


static func _prism(material: ShaderMaterial, size: Vector3) -> PrismMesh:
	var key := "prism|%d|%.4f|%.4f|%.4f" % [material.get_instance_id(),
		size.x, size.y, size.z]
	var cached := _mesh_cache.get(key) as PrismMesh
	if cached != null:
		return cached
	var mesh := PrismMesh.new()
	mesh.size = size
	mesh.material = material
	_mesh_cache[key] = mesh
	return mesh


static func _cylinder(material: ShaderMaterial, top: float, bottom: float,
		height: float, segments: int) -> CylinderMesh:
	var key := "cyl|%d|%.4f|%.4f|%.4f|%d" % [material.get_instance_id(),
		top, bottom, height, segments]
	var cached := _mesh_cache.get(key) as CylinderMesh
	if cached != null:
		return cached
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mesh.material = material
	_mesh_cache[key] = mesh
	return mesh


static func _torus(material: ShaderMaterial, inner: float, outer: float,
		tube_segments: int, ring_slices: int) -> TorusMesh:
	var safe_inner := maxf(0.002, inner)
	var safe_outer := maxf(safe_inner + 0.002, outer)
	var key := "torus|%d|%.4f|%.4f|%d|%d" % [material.get_instance_id(),
		safe_inner, safe_outer, tube_segments, ring_slices]
	var cached := _mesh_cache.get(key) as TorusMesh
	if cached != null:
		return cached
	var mesh := TorusMesh.new()
	mesh.inner_radius = safe_inner
	mesh.outer_radius = safe_outer
	# `rings` slices the main circle and decides whether the ring reads as a
	# circle or a polygon; `ring_segments` is only the tube cross-section.
	mesh.rings = ring_slices
	mesh.ring_segments = tube_segments
	mesh.material = material
	_mesh_cache[key] = mesh
	return mesh


static func _sphere(material: ShaderMaterial, radius: float) -> SphereMesh:
	var key := "sphere|%d|%.4f" % [material.get_instance_id(), radius]
	var cached := _mesh_cache.get(key) as SphereMesh
	if cached != null:
		return cached
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = material
	_mesh_cache[key] = mesh
	return mesh
