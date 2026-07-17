extends Node
## UI theme helper (autoload "UI").
## Decorates Buttons with a beveled (diagonal-cut) shader background that also
## provides the pulsing lava focus glow — see scripts/ui_bevel.gdshader.
## StyleBoxes stay empty in the Theme; the visuals live on a ColorRect placed
## behind each button so the pixel-font text is never touched by the shader.

const BEVEL_MAT := preload("res://scripts/ui_bevel_material.tres")
const RUBIK := preload("res://assets/fonts/Rubik-VariableFont_wght.ttf")

var _rubik_bold: FontVariation


func _ready() -> void:
	_rubik_bold = FontVariation.new()
	_rubik_bold.base_font = RUBIK
	_rubik_bold.variation_opentype = {2003265652: 700}  # wght = Bold

# Palette (kit "Deep Slate" + lava accents)
const C_SLATE := Color(0.173, 0.141, 0.212)        # #2c2436  secondary bg
const C_SLATE_BORDER := Color(0.259, 0.227, 0.306) # #423a4e
const C_SLATE_HOVER := Color(0.216, 0.18, 0.263)
const C_PANEL := Color(0.129, 0.106, 0.169)        # #211b2b
const C_PANEL_BORDER := Color(0.196, 0.169, 0.239) # #322b3d
const C_LAVA_A := Color(1.0, 0.353, 0.122)         # #ff5a1f
const C_LAVA_B := Color(1.0, 0.541, 0.239)         # #ff8a3d
const C_LAVA_DEEP := Color(0.722, 0.2, 0.102)      # #b8331a
const C_INK := Color(0.949, 0.925, 0.894)          # #f2ece4
const C_MUTED := Color(0.612, 0.561, 0.651)        # #9c8fa6
const C_ON_ACCENT := Color(0.102, 0.059, 0.031)    # #1a0f08


## Decorate every direct-child Button of `container`.
func decorate_buttons(container: Node, variant: String = "secondary") -> void:
	if container == null:
		return
	for c in container.get_children():
		if c is Button:
			decorate_button(c, variant)


## Recursively decorate every Button under `root`, EXCEPT those that already
## carry a custom "normal" stylebox override (e.g. toggle sub-tabs or the
## green/red confirm/cancel buttons keep their own look) or are already done.
func decorate_all(root: Node, variant: String = "secondary") -> void:
	if root == null:
		return
	for btn in _find_buttons(root):
		if btn.has_node("_LavaBg"):
			continue
		# checkboxes / toggle switches / radios keep their 1c icon look (no button
		# background) but still get a lava-pulse focus ring via the "ghost" variant.
		if btn is CheckBox or btn is CheckButton:
			decorate_button(btn, "ghost")
			continue
		if btn.has_theme_stylebox_override("normal"):
			continue
		decorate_button(btn, variant)


func _find_buttons(node: Node, acc: Array = []) -> Array:
	for c in node.get_children():
		if c is Button:
			acc.append(c)
		if c.get_child_count() > 0:
			_find_buttons(c, acc)
	return acc


## Decorate a single Button. Idempotent.
func decorate_button(btn: Button, variant: String = "secondary") -> void:
	if btn == null or btn.has_node("_LavaBg"):
		return
	var bg := ColorRect.new()
	bg.name = "_LavaBg"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.show_behind_parent = true
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat: ShaderMaterial = BEVEL_MAT.duplicate()
	_apply_variant(mat, btn, variant)
	bg.material = mat
	btn.add_child(bg)
	btn.move_child(bg, 0)

	var _sync := func() -> void: mat.set_shader_parameter("rect_px", btn.size)
	bg.resized.connect(_sync)
	btn.resized.connect(_sync)
	_sync.call_deferred()

	btn.focus_entered.connect(func() -> void:
		mat.set_shader_parameter("rect_px", btn.size)  # ensure correct size when glow shows
		mat.set_shader_parameter("focused", 1.0))
	btn.focus_exited.connect(func() -> void: mat.set_shader_parameter("focused", 0.0))
	if btn.has_focus():
		mat.set_shader_parameter("rect_px", btn.size)
		mat.set_shader_parameter("focused", 1.0)

	btn.mouse_entered.connect(func() -> void: mat.set_shader_parameter("hovered", 1.0))
	btn.mouse_exited.connect(func() -> void: mat.set_shader_parameter("hovered", 0.0))
	btn.button_down.connect(func() -> void: mat.set_shader_parameter("pressed", 1.0))
	btn.button_up.connect(func() -> void: mat.set_shader_parameter("pressed", 0.0))


## Mark a decorated tab active: solid orange fill (dark text handled by caller)
## vs. transparent for inactive tabs (navbar shows through).
func set_tab_active(btn: Button, is_active: bool) -> void:
	if btn == null:
		return
	var bg := btn.get_node_or_null("_LavaBg")
	if bg and bg.material is ShaderMaterial:
		(bg.material as ShaderMaterial).set_shader_parameter("active", 1.0 if is_active else 0.0)


## Build a static beveled-panel ShaderMaterial (e.g. for the tabs navbar).
func make_bevel_material(bg_c: Color, border_c: Color, bevel: float = 5.0, border: float = 0.0) -> ShaderMaterial:
	var mat: ShaderMaterial = BEVEL_MAT.duplicate()
	mat.set_shader_parameter("menu_style", 0.0)
	mat.set_shader_parameter("bg_color", bg_c)
	mat.set_shader_parameter("border_col", border_c)
	mat.set_shader_parameter("hover_col", bg_c)
	mat.set_shader_parameter("bevel_px", bevel)
	mat.set_shader_parameter("border_px", border)
	return mat


func _apply_variant(mat: ShaderMaterial, btn: Button, variant: String) -> void:
	match variant:
		"primary":
			mat.set_shader_parameter("bg_color", C_LAVA_A)
			mat.set_shader_parameter("border_col", C_LAVA_DEEP)
			mat.set_shader_parameter("hover_col", C_LAVA_B)
			mat.set_shader_parameter("bevel_px", 5.0)
			mat.set_shader_parameter("bottom_bevel_px", 3.0)
			# dark text on the orange fill
			btn.add_theme_color_override("font_color", C_ON_ACCENT)
			btn.add_theme_color_override("font_hover_color", C_ON_ACCENT)
			btn.add_theme_color_override("font_pressed_color", C_ON_ACCENT)
			btn.add_theme_color_override("font_focus_color", C_ON_ACCENT)
		"menu":
			# 1b "Hlavné menu" list item: transparent until hover/focus.
			mat.set_shader_parameter("menu_style", 1.0)
			mat.set_shader_parameter("bevel_px", 4.0)
			btn.add_theme_color_override("font_color", C_MUTED)
			btn.add_theme_color_override("font_hover_color", C_INK)
			btn.add_theme_color_override("font_focus_color", C_INK)
			btn.add_theme_color_override("font_pressed_color", C_INK)
		"ghost":
			# transparent fill; only the lava-pulse focus ring shows (checkboxes).
			mat.set_shader_parameter("bg_color", Color(0, 0, 0, 0))
			mat.set_shader_parameter("border_col", C_LAVA_A)
			mat.set_shader_parameter("border_px", 2.0)
			mat.set_shader_parameter("bevel_px", 4.0)
		"tab":
			# navbar tab: transparent (bar shows through), bold body font, active=orange.
			mat.set_shader_parameter("menu_style", 1.0)
			mat.set_shader_parameter("bevel_px", 4.0)
			btn.add_theme_font_override("font", _rubik_bold)
			btn.add_theme_font_size_override("font_size", 13)
			btn.add_theme_color_override("font_color", C_MUTED)
			btn.add_theme_color_override("font_hover_color", C_INK)
		"panel":
			mat.set_shader_parameter("bg_color", C_PANEL)
			mat.set_shader_parameter("border_col", C_PANEL_BORDER)
			mat.set_shader_parameter("hover_col", C_PANEL)
			mat.set_shader_parameter("bevel_px", 5.0)
		_:  # secondary
			mat.set_shader_parameter("bg_color", C_SLATE)
			mat.set_shader_parameter("border_col", C_SLATE_BORDER)
			mat.set_shader_parameter("hover_col", C_SLATE_HOVER)
			mat.set_shader_parameter("bevel_px", 4.0)
