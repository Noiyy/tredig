## Rovnaká matematika ako v lava_pixel.gdshader (hash / vnoise / fbm).
## Načítava sa cez preload z lava.gd

static func _fract(x: float) -> float:
	return x - floor(x)


static func _hash(p: Vector2) -> float:
	var px: float = p.x * 0.1031
	var py: float = p.y * 0.1030
	var pz: float = p.x * 0.0973
	var p3 := Vector3(_fract(px), _fract(py), _fract(pz))
	var q := Vector3(p3.y + 33.33, p3.z + 33.33, p3.x + 33.33)
	var d: float = p3.x * q.x + p3.y * q.y + p3.z * q.z
	p3 += Vector3(d, d, d)
	return _fract((p3.x + p3.y) * p3.z)


static func _vnoise(p: Vector2) -> float:
	var i := Vector2(floor(p.x), floor(p.y))
	var f := Vector2(_fract(p.x), _fract(p.y))
	var fx: float = f.x * f.x * (3.0 - 2.0 * f.x)
	var fy: float = f.y * f.y * (3.0 - 2.0 * f.y)
	var a: float = _hash(i)
	var b: float = _hash(i + Vector2(1.0, 0.0))
	var c: float = _hash(i + Vector2(0.0, 1.0))
	var d: float = _hash(i + Vector2(1.0, 1.0))
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func fbm(p: Vector2) -> float:
	var v: float = 0.0
	var a: float = 0.5
	var pp := p
	for _i in 4:
		v += a * _vnoise(pp)
		pp *= 2.03
		a *= 0.5
	return v


static func column_top_bottom_uv(col_norm: float, t: float, edge_h: float) -> Vector2:
	var surf_top: float = fbm(Vector2(col_norm * 4.2 + t * 0.13, 0.37)) * edge_h
	var bite_bottom: float = fbm(Vector2(col_norm * 4.2 + t * 0.09, 0.91)) * edge_h
	var y_max: float = 1.0 - bite_bottom
	return Vector2(surf_top, y_max)
