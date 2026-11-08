@tool
extends Control
## 斜めの六角の枠と、項目の絵。位置と倍率はノードで変えられる。
@export_enum("aero", "speed", "stamina", "notch", "dash", "boost") var kind := "speed"
@export var icon_color := Color.WHITE
@export var icon_size := 44.0
@export var frame_slant := -12.0
@export var frame_width := 3.0
@export var show_frame := true

const GLYPHS := {
	"speed": "<path d=\"M9 33 A16 16 0 1 1 39 33\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"4\" stroke-linecap=\"round\"/><path d=\"M24 31 L34 17\" stroke=\"#ffffff\" stroke-width=\"4\" stroke-linecap=\"round\"/><circle cx=\"24\" cy=\"31\" r=\"4\" fill=\"#ffffff\"/>",
	"stamina": "<rect x=\"7\" y=\"15\" width=\"30\" height=\"18\" rx=\"4\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"3.5\"/><rect x=\"38\" y=\"20\" width=\"4\" height=\"8\" rx=\"1.5\" fill=\"#ffffff\"/><rect x=\"11\" y=\"19\" width=\"7\" height=\"10\" rx=\"1.5\" fill=\"#ffffff\"/><rect x=\"20\" y=\"19\" width=\"7\" height=\"10\" rx=\"1.5\" fill=\"#ffffff\"/>",
	"aero": "<path d=\"M6 17 H28 a5 5 0 1 0 -5 -5\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"3.5\" stroke-linecap=\"round\"/><path d=\"M6 25 H36 a5 5 0 1 1 -5 5\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"3.5\" stroke-linecap=\"round\"/><path d=\"M6 33 H20\" stroke=\"#ffffff\" stroke-width=\"3.5\" stroke-linecap=\"round\"/>",
	"notch": "<g fill=\"none\" stroke=\"#ffffff\" stroke-width=\"3.5\" stroke-linecap=\"round\"><path d=\"M20 8V40\"/><path d=\"M29 9H35 M29 15H35 M29 21H35 M29 27H35 M29 33H35 M29 39H35\"/></g><rect x=\"12\" y=\"23\" width=\"16\" height=\"9\" rx=\"3\" fill=\"#ffffff\"/>",
	"dash": "<path d=\"M7 38 C10 24 22 10 43 7 C40 13 35 17 29 19 C35 19 39 18 42 17 C38 24 31 27 24 28 C29 29 33 29 36 28 C30 35 19 39 7 38 Z\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"3.2\" stroke-linejoin=\"round\"/><path d=\"M7 38 C16 30 24 22 34 13\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"3\" stroke-linecap=\"round\"/>",
	"boost": "<path d=\"M24 4 C31 10 33 19 32 31 L16 31 C15 19 17 10 24 4 Z\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"3.2\" stroke-linejoin=\"round\"/><circle cx=\"24\" cy=\"17\" r=\"3.6\" fill=\"#ffffff\"/><path d=\"M16 23 L9 34 L16 33 Z M32 23 L39 34 L32 33 Z\" fill=\"#ffffff\"/><path d=\"M19.5 34 L24 44 L28.5 34 Z\" fill=\"#ffffff\"/>",
}
var _key: Array = []
var _texture: ImageTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	var key := [kind, icon_color, icon_size, frame_slant, frame_width, show_frame]
	if key == _key:
		return
	_key = key
	var frame := '<path d="M14 2 H34 L46 24 L34 46 H14 L2 24 Z" fill="#0b1020" stroke="white" stroke-width="%s"/>' % frame_width if show_frame else ""
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="-8 -8 64 64"><g transform="translate(24 24) skewX(%s) translate(-24 -24)">%s<g transform="translate(24 24) scale(0.72) translate(-24 -24)">%s</g></g></svg>' % [frame_slant, frame, GLYPHS[kind]]
	var picture := Image.new()
	if picture.load_svg_from_string(svg, 3.0) == OK:
		_texture = ImageTexture.create_from_image(picture)
	queue_redraw()

func _draw() -> void:
	if _texture != null:
		var extent := icon_size * 64.0 / 48.0
		draw_texture_rect(_texture, Rect2(Vector2.ONE * -extent * 0.5, Vector2.ONE * extent), false, icon_color)
