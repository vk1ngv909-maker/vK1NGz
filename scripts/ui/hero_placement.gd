class_name HeroPlacement
extends RefCounted
## Where the hero stands, derived from the sprite's alpha bounds.
##
## The two hero poses are 2048x2048 with the character inside transparent
## padding, and they do not fill that square identically. Sizing and placing by
## the canvas would move the visible body when the pose swaps mid-swing, so
## everything here works from the baked bounds instead: the body is what gets
## the target height, and the body's bottom-centre is what lands on the anchor.
##
## Deliberately free of autoloads and node references so the same functions the
## arena runs can be driven directly by tests/unit/test_hero_assets.gd.

const DEFAULT_CANVAS: int = 2048


static func body_fraction(entry: Dictionary) -> float:
	## Share of the canvas height the visible body occupies.
	var canvas: Array = entry.get("canvas", [DEFAULT_CANVAS, DEFAULT_CANVAS])
	var box: Array = entry.get("bbox", [0, 0, canvas[0], canvas[1]])
	return float(int(box[3]) - int(box[1])) / maxf(1.0, float(canvas[1]))


static func rect_side(body_height: float, entry: Dictionary) -> float:
	## The square to draw the sprite into so the body ends up body_height tall.
	return body_height / maxf(0.01, body_fraction(entry))


static func body_offset(side: float, entry: Dictionary) -> Vector2:
	## Where the body's bottom-centre sits inside that square.
	var canvas: Array = entry.get("canvas", [DEFAULT_CANVAS, DEFAULT_CANVAS])
	var box: Array = entry.get("bbox", [0, 0, canvas[0], canvas[1]])
	return Vector2(
		side * (float(int(box[0]) + int(box[2])) * 0.5) / maxf(1.0, float(canvas[0])),
		side * float(int(box[3])) / maxf(1.0, float(canvas[1])))


static func placement(body_height: float, axis_x: float, ground_y: float, entry: Dictionary) -> Dictionary:
	## Rectangle side and top-left position for one pose. position + offset must
	## come out as (axis_x, ground_y) for every pose; that identity is what
	## keeps the hero from hopping on the frame the pose changes.
	var side: float = rect_side(body_height, entry)
	var offset: Vector2 = body_offset(side, entry)
	return {
		"side": side,
		"offset": offset,
		"position": Vector2(axis_x - offset.x, ground_y - offset.y),
	}
