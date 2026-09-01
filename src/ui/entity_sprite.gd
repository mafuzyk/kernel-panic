class_name EntitySprite
extends RefCounted

## Sprite trial registry (author-gated, non-default): per-entity path lookup
## with the code-drawn GlyphLib silhouettes as the shipped presentation. The
## generated sheets remain available for experiments, but the arena switch is
## deliberately closed until a visual pass proves facing, idle motion, hit
## feedback, and state readability at gameplay scale.

const SPRITE_DIR := "res://assets/sprites/generated/"

## Arena entities stay code-drawn until a sprite pass proves behavior parity:
## facing, idle motion, hit feedback, silhouettes at gameplay scale, and all
## state changes must read as well as the current GlyphLib drawings.
const SPRITES_ENABLED := false

static var _sprite_tex_cache := {}

static func sprites_enabled() -> bool:
	return SPRITES_ENABLED

## Per-entity sprite path; "" keeps the glyph fallback active. Renaming or
## subfolder rules live here only — call sites never touch the filesystem.
static func sprite_path(kind: String) -> String:
	if not SPRITES_ENABLED:
		return ""
	var path := SPRITE_DIR + kind + ".png"
	return path if ResourceLoader.exists(path) else ""

static func has_sprite(kind: String) -> bool:
	return not sprite_path(kind).is_empty()

static func sprite_texture(kind: String) -> Texture2D:
	var path := sprite_path(kind)
	if path.is_empty():
		return null
	if not _sprite_tex_cache.has(path):
		_sprite_tex_cache[path] = load(path)
	return _sprite_tex_cache[path]

static func clear_sprite_cache() -> void:
	_sprite_tex_cache.clear()

## Draws the entity sprite fitted to a square of `size_px` centered on
## `center`, tinted via vertex-color modulate (requires white-base art).
## Returns true when a sprite was drawn so GlyphLib can skip its fallback.
static func draw_entity(canvas: CanvasItem, kind: String, center: Vector2, size_px: float, tint: Color) -> bool:
	if canvas == null or size_px <= 0.0:
		return false
	var tex := sprite_texture(kind)
	if tex == null:
		return false
	var half := size_px * 0.5
	# Arena sprites stay non-rotating: rotating enemy nodes (drone, lancer,
	# oom, god) transform their own draw commands, so the quad corners counter
	# the canvas rotation and the sprite lands axis-aligned on the same
	# center point. UI call sites rotate by 0, so this is a no-op there, and
	# caller transforms keep positioning and scaling the sprite (bestiary
	# fit_scale, program card zoom). Tint flows through vertex colors exactly
	# like a draw_texture_rect modulate would.
	var angle: float = -canvas.get_global_transform().get_rotation()
	var corners := PackedVector2Array([
		center + Vector2(-half, -half).rotated(angle),
		center + Vector2(half, -half).rotated(angle),
		center + Vector2(half, half).rotated(angle),
		center + Vector2(-half, half).rotated(angle),
	])
	var uvs := PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	canvas.draw_polygon(corners, [tint, tint, tint, tint], uvs, tex)
	return true
