# src/player/ship_art.gd
#
# Authored vector art for the player ships and their attachments.
#
# Every silhouette is a *list of parts* rather than a single polygon, so a ship
# reads as an actual aircraft: swept wings, a fuselage with a lighter spine
# panel running down it, a canopy, tail fins and exhaust nozzles. Parts are
# authored in hull-local units with the nose pointing along +X (matching the
# player's `look_at()` rotation) and are drawn in list order, back to front.
#
# A part is a Dictionary:
#   points:  PackedVector2Array  -- the polygon
#   tone:    String              -- resolved against a base colour (see resolve_tone)
#   alpha:   float (optional)    -- overrides the tone's alpha
#   outline: bool (optional)     -- draw a dark expanded copy behind this part
#   outline_width: float (optional, default 1.6)
#
# Both the in-mission player ship and the hangar preview build from this same
# data, so what you buy in the hangar is exactly what you fly.
class_name ShipArt
extends RefCounted

const SHIP_IDS := ["interceptor", "juggernaut", "razor"]

# --- Tone resolution ------------------------------------------------------

# Tones are named roles, not fixed colours: hull tones derive from the ship's
# (or the upgrade category's) base colour so one palette drives every part.
static func resolve_tone(tone: String, base: Color) -> Color:
	match tone:
		"outline": return Color(0.04, 0.05, 0.09, 1.0)
		"dark": return base.darkened(0.6)
		"mid": return base.darkened(0.25)
		"light": return base.lightened(0.2)
		"trim": return base.lightened(0.55)
		"canopy": return Color(0.07, 0.11, 0.2, 1.0)
		"canopy_glint": return Color(0.72, 0.92, 1.0, 0.85)
		"metal": return Color(0.46, 0.5, 0.58, 1.0)
		"metal_dark": return Color(0.2, 0.23, 0.3, 1.0)
		"accent": return Color(1.0, 0.72, 0.25, 1.0)
		"glow": return Color(0.6, 0.9, 1.0, 0.85)
		_: return base

# --- Geometry helpers -----------------------------------------------------

# Mirrors a polygon across the ship's long axis, reversing winding so the
# mirrored copy keeps the same orientation as the original.
static func mirror_y(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(points.size() - 1, -1, -1):
		out.append(Vector2(points[i].x, -points[i].y))
	return out

# Pushes every vertex away from the polygon's centroid, producing the dark
# backing shape used as a cheap per-part outline (no Line2D, no shader).
static func expand(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	if points.size() == 0:
		return points
	var centroid := Vector2.ZERO
	for p in points:
		centroid += p
	centroid /= float(points.size())
	var out := PackedVector2Array()
	for p in points:
		var dir := p - centroid
		if dir.length() < 0.001:
			out.append(p)
		else:
			out.append(p + dir.normalized() * amount)
	return out

static func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

# Annulus sector, used for shield emitter bands that wrap around the hull.
static func arc_band(r_inner: float, r_outer: float, deg_from: float, deg_to: float, segments: int = 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := deg_to_rad(lerpf(deg_from, deg_to, float(i) / float(segments)))
		pts.append(Vector2(cos(a), sin(a)) * r_outer)
	for i in range(segments, -1, -1):
		var a := deg_to_rad(lerpf(deg_from, deg_to, float(i) / float(segments)))
		pts.append(Vector2(cos(a), sin(a)) * r_inner)
	return pts

static func _ring(r_inner: float, r_outer: float, sides: int = 12) -> PackedVector2Array:
	return arc_band(r_inner, r_outer, 0.0, 359.0, sides)

static func _part(points: PackedVector2Array, tone: String, outline: bool = false, alpha: float = -1.0) -> Dictionary:
	var d := {"points": points, "tone": tone}
	if outline:
		d["outline"] = true
	if alpha >= 0.0:
		d["alpha"] = alpha
	return d

# Appends a part and its mirrored twin, so wings/fins/pods stay symmetrical.
static func _pair(parts: Array[Dictionary], points: PackedVector2Array, tone: String, outline: bool = false, alpha: float = -1.0) -> void:
	parts.append(_part(points, tone, outline, alpha))
	parts.append(_part(mirror_y(points), tone, outline, alpha))

# --- Hulls ----------------------------------------------------------------

static func get_hull_parts(ship_id: String) -> Array[Dictionary]:
	match ship_id:
		"juggernaut": return _juggernaut_hull()
		"razor": return _razor_hull()
		_: return _interceptor_hull()

# Classic swept-wing strike fighter: canards up front, delta main wings,
# twin canted tail fins, twin exhausts.
static func _interceptor_hull() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []

	# Main delta wings, swept back from a root just ahead of mid-hull.
	_pair(parts, PackedVector2Array([
		Vector2(10, -3), Vector2(-6, -20), Vector2(-13, -19), Vector2(-10, -4),
	]), "dark", true)
	# Wing leading-edge highlight so the sweep reads at a glance.
	_pair(parts, PackedVector2Array([
		Vector2(9, -4), Vector2(-6, -18.5), Vector2(-8.5, -18), Vector2(-5, -5),
	]), "mid")
	# Forward canards.
	_pair(parts, PackedVector2Array([
		Vector2(17, -2), Vector2(10, -10), Vector2(6, -9.5), Vector2(10, -2),
	]), "dark", true)
	# Canted tail fins.
	_pair(parts, PackedVector2Array([
		Vector2(-9, -5), Vector2(-15, -13), Vector2(-19, -12), Vector2(-15, -4),
	]), "dark", true)

	# Fuselage.
	parts.append(_part(PackedVector2Array([
		Vector2(26, 0), Vector2(20, -3), Vector2(8, -6), Vector2(-8, -7),
		Vector2(-14, -6), Vector2(-16, -4), Vector2(-16, 4), Vector2(-14, 6),
		Vector2(-8, 7), Vector2(8, 6), Vector2(20, 3),
	]), "mid", true))
	# Lighter dorsal spine panel.
	parts.append(_part(PackedVector2Array([
		Vector2(22, 0), Vector2(10, -3.2), Vector2(-8, -3.8), Vector2(-14, -2.6),
		Vector2(-14, 2.6), Vector2(-8, 3.8), Vector2(10, 3.2),
	]), "light"))
	# Nose cone.
	parts.append(_part(PackedVector2Array([
		Vector2(26, 0), Vector2(21, -2.2), Vector2(17.5, 0), Vector2(21, 2.2),
	]), "trim"))

	# Canopy + glint.
	parts.append(_part(PackedVector2Array([
		Vector2(16, 0), Vector2(11, -2.8), Vector2(4, -3.2), Vector2(0, -2),
		Vector2(-2, 0), Vector2(0, 2), Vector2(4, 3.2), Vector2(11, 2.8),
	]), "canopy", true))
	parts.append(_part(PackedVector2Array([
		Vector2(13, -0.6), Vector2(8, -2.1), Vector2(3, -2.2), Vector2(2, -1.0),
	]), "canopy_glint"))

	# Exhaust nozzles.
	_pair(parts, _rect(-16, -5.2, -20.5, -1.4), "metal_dark", true)
	_pair(parts, _rect(-19.5, -4.6, -21.5, -2.0), "glow")

	# Wingtip nav lights.
	_pair(parts, _rect(-7.5, -19.5, -10.5, -17.5), "accent")
	return parts

# Heavy gunship: blunt ram prow, armoured sponsons, stub wings, quad exhausts.
static func _juggernaut_hull() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []

	# Outboard stub wings.
	_pair(parts, PackedVector2Array([
		Vector2(2, -20), Vector2(-7, -27), Vector2(-16, -25), Vector2(-12, -19),
	]), "dark", true)
	# Armoured shoulder sponsons.
	_pair(parts, PackedVector2Array([
		Vector2(8, -11), Vector2(3, -22), Vector2(-12, -24), Vector2(-17, -13),
	]), "mid", true)
	_pair(parts, PackedVector2Array([
		Vector2(5, -13), Vector2(1.5, -20.5), Vector2(-11, -22), Vector2(-14.5, -14),
	]), "dark")

	# Fuselage.
	parts.append(_part(PackedVector2Array([
		Vector2(22, 0), Vector2(19, -6), Vector2(8, -12), Vector2(-10, -14),
		Vector2(-18, -12), Vector2(-21, -6), Vector2(-21, 6), Vector2(-18, 12),
		Vector2(-10, 14), Vector2(8, 12), Vector2(19, 6),
	]), "mid", true))
	# Dorsal armour deck.
	parts.append(_part(PackedVector2Array([
		Vector2(18, 0), Vector2(9, -7), Vector2(-10, -8.5), Vector2(-17.5, -5),
		Vector2(-17.5, 5), Vector2(-10, 8.5), Vector2(9, 7),
	]), "light"))
	# Ram prow.
	parts.append(_part(PackedVector2Array([
		Vector2(22, 0), Vector2(18, -5.5), Vector2(13.5, 0), Vector2(18, 5.5),
	]), "metal", true))

	# Armoured cockpit slit.
	parts.append(_part(PackedVector2Array([
		Vector2(15, 0), Vector2(10, -4.2), Vector2(3, -4.6), Vector2(1, 0),
		Vector2(3, 4.6), Vector2(10, 4.2),
	]), "canopy", true))
	parts.append(_part(PackedVector2Array([
		Vector2(12.5, -1.0), Vector2(8, -3.2), Vector2(4, -3.4), Vector2(3.5, -1.6),
	]), "canopy_glint"))

	# Hull rib stripes.
	_pair(parts, _rect(-2, -8.0, -5, -3.0), "trim")
	_pair(parts, _rect(-9, -8.0, -12, -3.0), "trim")

	# Quad exhausts.
	_pair(parts, _rect(-21, -11.0, -25, -6.5), "metal_dark", true)
	_pair(parts, _rect(-21, -4.5, -25.5, -0.8), "metal_dark", true)
	_pair(parts, _rect(-24, -10.2, -26, -7.4), "glow")
	_pair(parts, _rect(-24.5, -3.8, -26.5, -1.5), "glow")
	return parts

# Stealth needle: long nose, forward strakes, deep-swept wings, single big engine.
static func _razor_hull() -> Array[Dictionary]:
	var parts: Array[Dictionary] = []

	# Deep-swept main wings.
	_pair(parts, PackedVector2Array([
		Vector2(5, -2.5), Vector2(-8, -15), Vector2(-16, -16), Vector2(-12, -3.5),
	]), "dark", true)
	_pair(parts, PackedVector2Array([
		Vector2(4, -3.5), Vector2(-8, -13.5), Vector2(-11, -13.5), Vector2(-8, -4.5),
	]), "mid")
	# Forward chine strakes.
	_pair(parts, PackedVector2Array([
		Vector2(19, -1.5), Vector2(9, -6.5), Vector2(3, -5.5), Vector2(7, -1.5),
	]), "dark", true)
	# Rear fins.
	_pair(parts, PackedVector2Array([
		Vector2(-8, -4), Vector2(-14, -11), Vector2(-17.5, -10), Vector2(-13, -3),
	]), "dark", true)

	# Fuselage.
	parts.append(_part(PackedVector2Array([
		Vector2(32, 0), Vector2(24, -2), Vector2(6, -4.5), Vector2(-8, -5.5),
		Vector2(-14, -4.5), Vector2(-14, 4.5), Vector2(-8, 5.5), Vector2(6, 4.5),
		Vector2(24, 2),
	]), "mid", true))
	parts.append(_part(PackedVector2Array([
		Vector2(28, 0), Vector2(12, -2.2), Vector2(-7, -2.8), Vector2(-12.5, -2.0),
		Vector2(-12.5, 2.0), Vector2(-7, 2.8), Vector2(12, 2.2),
	]), "light"))
	parts.append(_part(PackedVector2Array([
		Vector2(32, 0), Vector2(26, -1.6), Vector2(22, 0), Vector2(26, 1.6),
	]), "trim"))

	# Long narrow canopy.
	parts.append(_part(PackedVector2Array([
		Vector2(19, 0), Vector2(13, -2.0), Vector2(5, -2.4), Vector2(1, -1.2),
		Vector2(-0.5, 0), Vector2(1, 1.2), Vector2(5, 2.4), Vector2(13, 2.0),
	]), "canopy", true))
	parts.append(_part(PackedVector2Array([
		Vector2(16, -0.5), Vector2(10, -1.6), Vector2(5, -1.7), Vector2(4, -0.7),
	]), "canopy_glint"))

	# Single large exhaust.
	parts.append(_part(_rect(-14, -4.0, -19, 4.0), "metal_dark", true))
	parts.append(_part(_rect(-18, -3.2, -20.5, 3.2), "glow"))
	_pair(parts, _rect(-13, -15.5, -15.5, -13.5), "accent")
	return parts

# --- Per-ship attach points ----------------------------------------------

# Attachments are authored around a per-ship anchor so pods sit on the wings
# and nacelles sit behind the engine deck rather than floating at a shared,
# one-size-fits-nobody offset.
const _ATTACH_OFFSETS := {
	"interceptor": {
		"weapons": Vector2(-1, 0), "engine": Vector2(-17, 0),
		"shield": Vector2(2, 0), "armor": Vector2(0, 0),
	},
	"juggernaut": {
		"weapons": Vector2(-3, 0), "engine": Vector2(-22, 0),
		"shield": Vector2(0, 0), "armor": Vector2(0, 0),
	},
	"razor": {
		"weapons": Vector2(-2, 0), "engine": Vector2(-18, 0),
		"shield": Vector2(4, 0), "armor": Vector2(2, 0),
	},
}

# How far out along the wing a weapon pod sits, per ship, so the Juggernaut's
# pods ride its wide sponsons while the Razor's hug its narrow wings.
const _WEAPON_SPANS := {"interceptor": 14.0, "juggernaut": 19.0, "razor": 11.5}
const _SHIELD_RADII := {"interceptor": 20.0, "juggernaut": 27.0, "razor": 17.0}

# Where the nose ends, per hull, so shots leave the barrel instead of the
# middle of a long fuselage (the Razor's nose reaches a lot further than the
# Juggernaut's blunt prow).
const _MUZZLE_OFFSETS := {
	"interceptor": Vector2(28, 0), "juggernaut": Vector2(24, 0), "razor": Vector2(34, 0),
}

static func get_muzzle_offset(ship_id: String) -> Vector2:
	return _MUZZLE_OFFSETS.get(ship_id, Vector2(28, 0))

static func get_attach_offset(ship_id: String, category: String) -> Vector2:
	var ship: Dictionary = _ATTACH_OFFSETS.get(ship_id, _ATTACH_OFFSETS["interceptor"])
	return ship.get(category, Vector2.ZERO)

# --- Attachments ----------------------------------------------------------

# Tier 0 is the stock part: deliberately empty, so the hull reads clean until
# the player actually buys something and sees new hardware bolted on.
static func get_attachment_parts(category: String, tier: int, ship_id: String = "interceptor") -> Array[Dictionary]:
	if tier <= 0:
		return []
	match category:
		"weapons": return _weapon_parts(tier, _WEAPON_SPANS.get(ship_id, 12.0))
		"engine": return _engine_parts(tier)
		"shield": return _shield_parts(tier, _SHIELD_RADII.get(ship_id, 18.0))
		"armor": return _armor_parts(tier)
		_: return []

# Wing-mounted cannon pods; tier 2 doubles up into a four-barrel rail array.
static func _weapon_parts(tier: int, span: float) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	if tier == 1:
		var pod := PackedVector2Array([
			Vector2(-7, -span - 2.5), Vector2(6, -span - 2.8), Vector2(9, -span),
			Vector2(6, -span + 2.8), Vector2(-7, -span + 2.5),
		])
		_pair(parts, pod, "mid", true)
		_pair(parts, _rect(8.5, -span - 1.0, 13.0, -span + 1.0), "metal", true)
		_pair(parts, _rect(12.5, -span - 0.8, 14.0, -span + 0.8), "glow")
		_pair(parts, _rect(-6, -span - 1.2, 1, -span + 1.2), "light")
	else:
		var inner := span - 3.5
		var outer := span + 4.0
		for y in [inner, outer]:
			var pod := PackedVector2Array([
				Vector2(-9, -y - 2.8), Vector2(7, -y - 3.0), Vector2(10, -y),
				Vector2(7, -y + 3.0), Vector2(-9, -y + 2.6),
			])
			_pair(parts, pod, "mid", true)
			_pair(parts, _rect(9.5, -y - 1.1, 17.0, -y + 1.1), "metal", true)
			_pair(parts, _rect(16.0, -y - 0.9, 18.0, -y + 0.9), "glow")
			_pair(parts, _rect(-8, -y - 1.3, 2, -y + 1.3), "light")
		# Rail coupling spine tying the two barrels of each side together.
		_pair(parts, _rect(-6, -outer + 1.0, 4, -inner - 1.0), "dark", true)
	return parts

# Nacelles bolted to the tail. They sit *behind* the hull in the draw order, so
# they're anchored well aft of the fuselage — otherwise the hull would cover
# them completely and the upgrade would look like it did nothing.
static func _engine_parts(tier: int) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	if tier == 1:
		var nacelle := PackedVector2Array([
			Vector2(5, -8.0), Vector2(-5, -8.5), Vector2(-8, -6.0),
			Vector2(-8, -2.5), Vector2(-5, -2.0), Vector2(5, -2.5),
		])
		_pair(parts, nacelle, "mid", true)
		_pair(parts, _rect(-7.5, -7.6, -11.0, -3.0), "metal_dark", true)
		_pair(parts, _rect(-10.5, -7.0, -14.0, -3.6), "glow")
		_pair(parts, _rect(2, -7.6, 5, -3.0), "trim")
	else:
		var nacelle := PackedVector2Array([
			Vector2(7, -11.0), Vector2(-5, -12.0), Vector2(-9, -8.0),
			Vector2(-9, -3.0), Vector2(-5, -2.5), Vector2(7, -3.5),
		])
		_pair(parts, nacelle, "mid", true)
		# Intake ring at the front of each nacelle.
		_pair(parts, _rect(5.5, -11.2, 8.5, -3.4), "metal", true)
		_pair(parts, _rect(-8.5, -11.0, -13.5, -3.6), "metal_dark", true)
		_pair(parts, _rect(-12.5, -9.8, -18.0, -4.6), "glow")
		_pair(parts, _rect(-3, -10.4, 3, -4.4), "light")
		# Centre booster slung between the two nacelles.
		parts.append(_part(_rect(2, -2.6, -8, 2.6), "dark", true))
		parts.append(_part(_rect(-7.5, -2.2, -13.0, 2.2), "glow"))
	return parts

# Emitter bands that wrap the hull; tier 2 closes into a full ring with nodes.
static func _shield_parts(tier: int, radius: float) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	if tier == 1:
		# Two open brackets fore and aft, plus the emitter nubs they hang off,
		# kept faint so the hull underneath stays the thing you look at.
		parts.append(_part(arc_band(radius, radius + 1.6, -52.0, 52.0, 12), "light", false, 0.4))
		parts.append(_part(arc_band(radius, radius + 1.6, 128.0, 232.0, 12), "light", false, 0.4))
		for angle in [-52.0, 52.0, 128.0, 232.0]:
			var p := Vector2(cos(deg_to_rad(angle)), sin(deg_to_rad(angle))) * (radius + 0.8)
			parts.append(_part(_rect(p.x - 1.6, p.y - 1.6, p.x + 1.6, p.y + 1.6), "trim", false, 0.85))
	else:
		# Closed emitter ring with six nodes — visibly a full bubble, still faint.
		parts.append(_part(_ring(radius + 1.4, radius + 3.0, 16), "mid", false, 0.22))
		parts.append(_part(_ring(radius, radius + 1.4, 16), "light", false, 0.5))
		for i in 6:
			var angle := (TAU / 6.0) * i
			var p := Vector2(cos(angle), sin(angle)) * (radius + 0.7)
			parts.append(_part(_rect(p.x - 2.0, p.y - 2.0, p.x + 2.0, p.y + 2.0), "trim", false, 0.85))
	return parts

# Bolt-on plating that straddles the fuselage flanks and wing roots. It is
# deliberately kept off the ship's centreline so it never covers the canopy —
# the cockpit is the strongest "this is an aircraft" cue the hull has.
static func _armor_parts(tier: int) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	if tier == 1:
		# Flank plates over the wing roots: blunt, bevelled slabs rather than
		# pointed shapes, so they never get mistaken for a second pair of wings.
		_pair(parts, PackedVector2Array([
			Vector2(-12, -11.5), Vector2(1, -11.5), Vector2(4, -9.0),
			Vector2(1, -6.5), Vector2(-12, -6.5),
		]), "mid", true)
		_pair(parts, _rect(-10, -10.4, 0, -7.6), "light")
		# Tail bumper across the rear deck.
		parts.append(_part(_rect(-11, -7.0, -15, 7.0), "mid", true))
		parts.append(_part(_rect(-12, -5.6, -14, 5.6), "light"))
	else:
		_pair(parts, PackedVector2Array([
			Vector2(-14, -13.5), Vector2(2, -13.5), Vector2(6, -10.0),
			Vector2(2, -6.5), Vector2(-14, -6.5),
		]), "mid", true)
		_pair(parts, _rect(-12, -12.4, 1, -10.6), "light")
		_pair(parts, _rect(-12, -9.4, 1, -7.6), "dark")
		# Shoulder guards riding above the flank plates.
		_pair(parts, PackedVector2Array([
			Vector2(-14, -14.0), Vector2(-6, -14.0), Vector2(-4, -19.0),
			Vector2(-13, -19.5),
		]), "dark", true)
		parts.append(_part(_rect(-11, -8.5, -17, 8.5), "mid", true))
		parts.append(_part(_rect(-12, -7.0, -16, 7.0), "light"))
		_pair(parts, _rect(-12.5, -8.0, -15.5, -4.0), "dark")
	return parts

# --- Node construction ----------------------------------------------------

# Builds a part list into Polygon2D children of `parent`. Outlined parts get a
# dark expanded copy drawn first, which doubles as the panel gap between parts.
static func build_parts(parent: Node2D, parts: Array[Dictionary], base: Color) -> void:
	for part in parts:
		var points: PackedVector2Array = part["points"]
		if points.size() < 3:
			continue
		if part.get("outline", false):
			var outline := Polygon2D.new()
			outline.polygon = expand(points, part.get("outline_width", 1.6))
			outline.color = resolve_tone("outline", base)
			parent.add_child(outline)
		var poly := Polygon2D.new()
		poly.polygon = points
		poly.color = resolve_tone(part.get("tone", "mid"), base)
		if part.has("alpha"):
			poly.color.a = part["alpha"]
		parent.add_child(poly)

# Convenience for UI: a standalone Node2D holding one part list, used for the
# upgrade-card icons in the hangar shop.
static func build_part_node(parts: Array[Dictionary], base: Color, art_scale: float = 1.0) -> Node2D:
	var root := Node2D.new()
	root.scale = Vector2(art_scale, art_scale)
	build_parts(root, parts, base)
	return root
