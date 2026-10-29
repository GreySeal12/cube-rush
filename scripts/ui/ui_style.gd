class_name UiStyle
extends RefCounted
## Style commun de l'interface (boutons arrondis, grosses polices lisibles).
## Un seul endroit à modifier pour changer l'apparence de tous les écrans.

const TEXT := Color(0.16, 0.17, 0.3)
const PRIMARY := Color(1.0, 0.45, 0.62)
const PRIMARY_DARK := Color(0.85, 0.3, 0.48)
const SECONDARY := Color(0.36, 0.62, 0.95)
const PANEL := Color(1, 1, 1, 0.95)
const STAR_ON := Color(1.0, 0.78, 0.18)
const STAR_OFF := Color(0.8, 0.82, 0.9)

## Taille minimale d'une zone tactile, en pixels de la résolution de
## référence 720×1280 (≈ 2× la recommandation de 48 dp).
const MIN_TOUCH := 96

static var _theme: Theme


static func font(weight: float = 0.6) -> Font:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = weight
	return f


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 36

	t.set_stylebox("normal", "Button", _box(PRIMARY, PRIMARY_DARK))
	t.set_stylebox("hover", "Button", _box(PRIMARY.lightened(0.08), PRIMARY_DARK))
	t.set_stylebox("pressed", "Button", _box(PRIMARY_DARK, PRIMARY_DARK.darkened(0.2), true))
	t.set_stylebox("disabled", "Button", _box(Color(0.78, 0.8, 0.86), Color(0.66, 0.68, 0.75)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.8))
	t.set_font_size("font_size", "Button", 44)

	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 36)

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.set_corner_radius_all(40)
	panel.content_margin_left = 40
	panel.content_margin_right = 40
	panel.content_margin_top = 40
	panel.content_margin_bottom = 40
	panel.shadow_color = Color(0, 0, 0, 0.18)
	panel.shadow_size = 16
	panel.shadow_offset = Vector2(0, 8)
	t.set_stylebox("panel", "PanelContainer", panel)
	_theme = t
	return t


## Style « bonbon » : fond coloré + bordure inférieure épaisse (effet 3D).
static func _box(bg: Color, border: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_bottom = 4 if pressed else 10
	s.set_corner_radius_all(32)
	s.content_margin_left = 32
	s.content_margin_right = 32
	s.content_margin_top = 18 + (6 if pressed else 0)
	s.content_margin_bottom = 18
	return s


## Variante de couleur pour un bouton secondaire.
static func make_secondary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _box(SECONDARY, SECONDARY.darkened(0.25)))
	button.add_theme_stylebox_override("hover", _box(SECONDARY.lightened(0.08), SECONDARY.darkened(0.25)))
	button.add_theme_stylebox_override("pressed", _box(SECONDARY.darkened(0.15), SECONDARY.darkened(0.35), true))


## Dégradé vertical (fonds d'écran).
static func gradient_texture(top: Color, bottom: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	return tex


## Marges pour éviter l'encoche / les coins arrondis des téléphones,
## converties dans les coordonnées de l'interface.
static func safe_margins(node: CanvasItem) -> Dictionary:
	var out := {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0:
		return out
	var view := node.get_viewport_rect().size
	var sx := view.x / float(screen.x)
	var sy := view.y / float(screen.y)
	out.left = maxf(safe.position.x * sx, 0.0)
	out.top = maxf(safe.position.y * sy, 0.0)
	out.right = maxf((screen.x - safe.end.x) * sx, 0.0)
	out.bottom = maxf((screen.y - safe.end.y) * sy, 0.0)
	# Sur PC, la « zone sûre » n'a pas de sens : pas de marge.
	if not OS.has_feature("mobile"):
		return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}
	return out
