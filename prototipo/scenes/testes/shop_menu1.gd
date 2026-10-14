extends Control

## LOJA COMPLETA (Skins, Eficiência, Fortuna, Extras) - Godot 4.2+
## Não precisa de nenhuma imagem: toda a interface e todos os ícones são
## gerados por código (ícones em SVG embutido, rasterizados em tempo de execução).
##
## USO: anexe este script a um nó Control (ou use a cena shop_menu.tscn).
## OPCIONAL: se quiser usar suas próprias artes, coloque PNGs em icons_folder
## com os nomes: skin_<id>.png, efficiency_<n>.png, fortune_<n>.png,
## extra_<id>.png, tab_<id>.png, coin.png, shop_icon.png. Se existir, substitui o SVG.

signal item_purchased(category: String, item_id: String)
signal skin_equipped(skin_id: String)
signal coins_changed(new_amount: int)
signal closed

@export var panel_size := Vector2(560, 720)
@export var coins: int = 1000
@export var icons_folder := "res://assets/shop/"
@export var play_open_animation := true

# ======================= CORES =======================
const OUT := "#150f2e"
const C_DIM := Color(0, 0, 0, 0.65)
var C_BG := Color("0b2150")
var C_BORDER := Color("2a6fd1")
var C_HEADER := Color("0e2b63")
var C_ROW := Color("0c2554")
var C_ROW_BORDER := Color("1a468f")
var C_FRAME_BG := Color("0a1c40")
var C_TAB := Color("0d2a5e")
var C_TAB_BORDER := Color("1f5cb8")
var C_TAB_ACTIVE := Color("1b7fe0")
var C_TAB_ACTIVE_BORDER := Color("63e0ff")
var C_NAME := Color("f1d6ff")
var C_DESC := Color("bcd4ff")
var C_GREEN := Color("3fae3f")
var C_GREEN_HOVER := Color("52c652")
var C_GREEN_DARK := Color("1f6b1f")
var C_BLUE_BTN := Color("2a6fd1")
var C_GREY := Color("2b3b5c")
var C_RED := Color("e0414b")

# ======================= DADOS =======================
var TABS := [
	{"id": "skins",      "title": "Skins",      "page_title": "Skins de Picareta",      "subtitle": "Deixe sua picareta com o seu estilo!"},
	{"id": "efficiency", "title": "Eficiência", "page_title": "Eficiência da Picareta", "subtitle": "Deixe sua picareta ainda mais eficiente!"},
	{"id": "fortune",    "title": "Fortuna",    "page_title": "Fortuna",                "subtitle": "Mais sorte para encontrar tesouros!"},
	{"id": "extras",     "title": "Extras",     "page_title": "Extras",                 "subtitle": "Itens especiais para a sua jornada!"},
]

var SKINS := [
	{"id": "basica",    "name": "Picareta Básica",     "desc": "O visual clássico para os verdadeiros mineradores.", "price": 0,    "rarity": "padrao",   "handle": "#b5651d", "head": "#aab2c5", "edge": "#e6ecff"},
	{"id": "dourada",   "name": "Picareta Dourada",    "desc": "Brilho e estilo para sua jornada.",                  "price": 500,  "rarity": "rara",     "handle": "#c27a1a", "head": "#ffb81c", "edge": "#fff0a0"},
	{"id": "cristal",   "name": "Picareta de Cristal", "desc": "Mais beleza para suas minas.",                       "price": 1500, "rarity": "epica",    "handle": "#8fa0b8", "head": "#4fd0ff", "edge": "#d4f6ff"},
	{"id": "vulcanica", "name": "Picareta Vulcânica",  "desc": "O poder do fogo em suas mãos.",                      "price": 3000, "rarity": "lendaria", "handle": "#4a2f2f", "head": "#3a1f1f", "edge": "#ff7a2a"},
]

var RARITIES := {
	"padrao":   {"label": "Padrão",   "color": Color("2b3b5c")},
	"rara":     {"label": "Rara",     "color": Color("1f5fd6")},
	"epica":    {"label": "Épica",    "color": Color("7a2fd0")},
	"lendaria": {"label": "Lendária", "color": Color("c4701a")},
}

# Comprados em ordem (I antes do II...). "hex" é a cor do ícone.
var EFFICIENCY_TIERS := [
	{"name": "Eficiência I",   "mult": 2.0,  "price": 50,     "hex": "#3a8bff"},
	{"name": "Eficiência II",  "mult": 3.0,  "price": 200,    "hex": "#3fd04a"},
	{"name": "Eficiência III", "mult": 4.0,  "price": 500,    "hex": "#38b6ff"},
	{"name": "Eficiência IV",  "mult": 5.0,  "price": 1000,   "hex": "#b455ff"},
	{"name": "Eficiência V",   "mult": 7.0,  "price": 5000,   "hex": "#ff9a1f"},
	{"name": "Eficiência X",   "mult": 20.0, "price": 100000, "hex": "#ff3b3b"},
]

# EXEMPLO - ajuste como quiser
var FORTUNE_TIERS := [
	{"name": "Fortuna I",   "mult": 1.2, "price": 100,  "hex": "#3fd04a"},
	{"name": "Fortuna II",  "mult": 1.5, "price": 400,  "hex": "#38b6ff"},
	{"name": "Fortuna III", "mult": 2.0, "price": 1500, "hex": "#b455ff"},
	{"name": "Fortuna IV",  "mult": 3.0, "price": 6000, "hex": "#ff9a1f"},
]

# EXEMPLO - ajuste como quiser (ids com ícone pronto: mochila, lanterna, ima, botas)
var EXTRAS := [
	{"id": "mochila",  "name": "Mochila Maior",  "desc": "Carrega mais minérios.",        "price": 250, "hex": "#3a8bff"},
	{"id": "lanterna", "name": "Lanterna",       "desc": "Enxergue melhor nas cavernas.", "price": 150, "hex": "#ffd23a"},
	{"id": "ima",      "name": "Ímã de Minério", "desc": "Atrai drops próximos.",         "price": 400, "hex": "#e0414b"},
	{"id": "botas",    "name": "Botas Rápidas",  "desc": "Move-se mais rápido.",          "price": 300, "hex": "#3fd04a"},
]

# ======================= ESTADO =======================
var owned_skins: Array = ["basica"]
var equipped_skin := "basica"
var levels := {"efficiency": 0, "fortune": 0}
var owned_extras: Array = []
var current_tab := 0

# ======================= UI =======================
var window: PanelContainer
var tab_buttons: Array[Button] = []
var page_title_label: Label
var page_subtitle_label: Label
var list_box: VBoxContainer
var coins_label: Label
var message_label: Label
var toast_tween: Tween
var _svg_cache := {}
var _warned := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_select_tab(0)
	_update_coins_label()
	if play_open_animation:
		_play_open()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()


# =====================================================================
#  API PÚBLICA
# =====================================================================
func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	_update_coins_label()
	if list_box != null:
		_populate_list()

func get_click_multiplier() -> float:
	var n: int = levels["efficiency"]
	return 1.0 if n == 0 else EFFICIENCY_TIERS[n - 1]["mult"]

func get_fortune_multiplier() -> float:
	var n: int = levels["fortune"]
	return 1.0 if n == 0 else FORTUNE_TIERS[n - 1]["mult"]

func get_equipped_skin() -> String:
	return equipped_skin

func has_extra(extra_id: String) -> bool:
	return extra_id in owned_extras

func open_shop() -> void:
	show()
	_populate_list(true)
	_play_open()

func close_shop() -> void:
	hide()
	closed.emit()

func get_save_data() -> Dictionary:
	return {"coins": coins, "owned_skins": owned_skins, "equipped_skin": equipped_skin,
		"levels": levels, "owned_extras": owned_extras}

func load_save_data(d: Dictionary) -> void:
	coins = d.get("coins", coins)
	owned_skins = d.get("owned_skins", owned_skins)
	equipped_skin = d.get("equipped_skin", equipped_skin)
	levels = d.get("levels", levels)
	owned_extras = d.get("owned_extras", owned_extras)
	if list_box != null:
		_update_coins_label()
		_populate_list()


# =====================================================================
#  ÍCONES (SVG gerados por código)
# =====================================================================
const SVG_HEAD := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'

func _svg_tex(svg: String) -> Texture2D:
	if _svg_cache.has(svg):
		return _svg_cache[svg]
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 2.0) # 64 -> 128 px
	if err != OK:
		push_warning("ShopMenu: falha ao rasterizar SVG")
		return null
	var tex := ImageTexture.create_from_image(img)
	_svg_cache[svg] = tex
	return tex

## Usa PNG do projeto se existir; senão, o SVG gerado.
func _icon(file_name: String, svg: String) -> Texture2D:
	var path := icons_folder + file_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	# O arquivo pode existir mas ainda não ter sido importado pela Godot
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if not _warned.has(path):
		_warned[path] = true
		print("ShopMenu: PNG não encontrado em '%s' -> usando ícone SVG" % path)
	return _svg_tex(svg)

func _svg_pickaxe(handle: String, head: String, edge: String) -> String:
	var s := SVG_HEAD
	s += '<line x1="12" y1="58" x2="46" y2="22" stroke="%s" stroke-width="11" stroke-linecap="round"/>' % OUT
	s += '<line x1="12" y1="58" x2="46" y2="22" stroke="%s" stroke-width="6" stroke-linecap="round"/>' % handle
	s += '<path d="M20 12 Q58 2 62 44 Q50 22 20 12 Z" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>' % [head, OUT]
	s += '<path d="M25 13 Q52 8 58 36" fill="none" stroke="%s" stroke-width="2" stroke-linecap="round" opacity="0.85"/>' % edge
	return s + "</svg>"

func _svg_bolt(color: String, arrow: bool) -> String:
	var s := SVG_HEAD
	s += '<circle cx="32" cy="32" r="30" fill="%s" opacity="0.18"/>' % color
	s += '<polygon points="38,4 16,34 29,34 24,60 50,26 36,26 46,4" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % [color, OUT]
	if arrow:
		s += '<polygon points="50,40 59,52 54,52 54,61 46,61 46,52 41,52" fill="#ffffff" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % OUT
	return s + "</svg>"

func _svg_clover(color: String) -> String:
	var s := SVG_HEAD
	s += '<path d="M32 38 Q34 52 44 60" fill="none" stroke="%s" stroke-width="6" stroke-linecap="round"/>' % OUT
	s += '<path d="M32 38 Q34 52 44 60" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % color
	var pts := [[23, 23], [41, 23], [23, 41], [41, 41]]
	for p in pts:
		s += '<circle cx="%d" cy="%d" r="14.5" fill="%s"/>' % [p[0], p[1], OUT]
	for p in pts:
		s += '<circle cx="%d" cy="%d" r="12" fill="%s"/>' % [p[0], p[1], color]
	s += '<circle cx="32" cy="32" r="7" fill="%s"/>' % color
	return s + "</svg>"

func _svg_star(color: String) -> String:
	var s := SVG_HEAD
	s += '<polygon points="32,4 39.05,22.29 58.63,23.35 43.41,35.71 48.46,54.65 32,44 15.54,54.65 20.59,35.71 5.37,23.35 24.95,22.29" fill="%s" stroke="%s" stroke-width="3.5" stroke-linejoin="round"/>' % [color, OUT]
	return s + "</svg>"

func _svg_coin() -> String:
	var s := SVG_HEAD
	s += '<circle cx="32" cy="32" r="28" fill="#ffc21a" stroke="#8a5a00" stroke-width="4"/>'
	s += '<circle cx="32" cy="32" r="19" fill="none" stroke="#ffe08a" stroke-width="3"/>'
	s += '<rect x="29" y="19" width="6" height="26" rx="3" fill="#ffe08a"/>'
	return s + "</svg>"

func _svg_shop() -> String:
	var s := SVG_HEAD
	s += '<rect x="12" y="24" width="40" height="30" rx="3" fill="#2a6fd1" stroke="%s" stroke-width="3"/>' % OUT
	s += '<rect x="12" y="40" width="40" height="7" fill="#8b5a2b" stroke="%s" stroke-width="2"/>' % OUT
	s += '<path d="M6 24 L12 8 H52 L58 24 Z" fill="#e0414b" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % OUT
	for x in [18, 30, 42]:
		s += '<polygon points="%d,9 %d,9 %d,23 %d,23" fill="#ffffff" opacity="0.9"/>' % [x, x + 6, x + 5, x - 1]
	s += '<circle cx="54" cy="52" r="8" fill="#ffc21a" stroke="#8a5a00" stroke-width="3"/>'
	return s + "</svg>"

func _svg_extra(id: String, color: String) -> String:
	var s := SVG_HEAD
	match id:
		"mochila":
			s += '<path d="M24 14 Q24 5 32 5 Q40 5 40 14" fill="none" stroke="%s" stroke-width="5"/>' % OUT
			s += '<rect x="14" y="14" width="36" height="44" rx="12" fill="%s" stroke="%s" stroke-width="3"/>' % [color, OUT]
			s += '<rect x="21" y="36" width="22" height="16" rx="5" fill="#ffffff" fill-opacity="0.3" stroke="%s" stroke-width="2"/>' % OUT
			s += '<line x1="14" y1="28" x2="50" y2="28" stroke="%s" stroke-width="3"/>' % OUT
		"lanterna":
			s += '<polygon points="20,8 44,8 38,28 26,28" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % [color, OUT]
			s += '<rect x="26" y="28" width="12" height="28" rx="3" fill="#8fa0b8" stroke="%s" stroke-width="3"/>' % OUT
			s += '<rect x="26" y="38" width="12" height="6" fill="#5b6b88"/>'
		"ima":
			s += '<path d="M16 12 V36 A16 16 0 0 0 48 36 V12" fill="none" stroke="%s" stroke-width="16"/>' % OUT
			s += '<path d="M16 12 V36 A16 16 0 0 0 48 36 V12" fill="none" stroke="%s" stroke-width="10"/>' % color
			s += '<line x1="16" y1="10" x2="16" y2="22" stroke="#ffffff" stroke-width="10"/>'
			s += '<line x1="48" y1="10" x2="48" y2="22" stroke="#ffffff" stroke-width="10"/>'
		"botas":
			s += '<polygon points="22,8 38,8 38,34 56,44 56,56 16,56 16,44 22,40" fill="%s" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % [color, OUT]
			s += '<rect x="16" y="50" width="40" height="6" fill="#ffffff" fill-opacity="0.4"/>'
		_:
			return _svg_star(color)
	return s + "</svg>"

func _tab_icon(id: String) -> Texture2D:
	match id:
		"skins":      return _icon("tab_skins.png", _svg_pickaxe("#b5651d", "#aab2c5", "#e6ecff"))
		"efficiency": return _icon("tab_efficiency.png", _svg_bolt("#ffc21a", false))
		"fortune":    return _icon("tab_fortune.png", _svg_clover("#3fd04a"))
		_:            return _icon("tab_extras.png", _svg_star("#ffc21a"))


# =====================================================================
#  HELPERS DE ESTILO / ANIMAÇÃO
# =====================================================================
func _box(bg: Color, border: Color, radius := 10, border_w := 2, pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	if pad > 0:
		s.set_content_margin_all(pad)
	return s

func _margin(n: int) -> MarginContainer:
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, n)
	return m

func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out

func _icon_rect(tex: Texture2D, size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _play_open() -> void:
	await get_tree().process_frame
	if window == null:
		return
	window.pivot_offset = window.size / 2.0
	window.scale = Vector2(0.92, 0.92)
	window.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(window, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(window, "modulate:a", 1.0, 0.15)

# Efeito de hover / clique nos botões
func _juicy(b: Button) -> void:
	b.resized.connect(_on_btn_resized.bind(b))
	b.mouse_entered.connect(_on_btn_hover.bind(b, true))
	b.mouse_exited.connect(_on_btn_hover.bind(b, false))
	b.button_down.connect(_on_btn_down.bind(b))
	b.button_up.connect(_on_btn_up.bind(b))

func _on_btn_resized(b: Button) -> void:
	b.pivot_offset = b.size / 2.0

func _on_btn_hover(b: Button, entered: bool) -> void:
	_tween_scale(b, 1.06 if (entered and not b.disabled) else 1.0)

func _on_btn_down(b: Button) -> void:
	_tween_scale(b, 0.94)

func _on_btn_up(b: Button) -> void:
	_tween_scale(b, 1.06 if (b.is_hovered() and not b.disabled) else 1.0)

func _tween_scale(n: Control, s: float) -> void:
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(s, s), 0.08)


# =====================================================================
#  CONSTRUÇÃO DA INTERFACE
# =====================================================================
func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = C_DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	window = PanelContainer.new()
	window.custom_minimum_size = panel_size
	var wstyle := _box(C_BG, C_BORDER, 18, 4)
	wstyle.shadow_color = Color(0, 0, 0, 0.6)
	wstyle.shadow_size = 18
	window.add_theme_stylebox_override("panel", wstyle)
	center.add_child(window)

	var margin := _margin(10)
	window.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)
	body.add_child(_build_sidebar())
	body.add_child(_build_content())

	root.add_child(_build_footer())


func _build_header() -> Control:
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _box(C_HEADER, C_BORDER, 14, 2, 8))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	header.add_child(h)

	h.add_child(_icon_rect(_icon("shop_icon.png", _svg_shop()), Vector2(60, 60)))

	var title := Label.new()
	title.text = "LOJA"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("e9dcff"))
	title.add_theme_color_override("font_outline_color", Color("1a1050"))
	title.add_theme_constant_override("outline_size", 8)
	h.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(52, 52)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.add_theme_stylebox_override("normal", _box(C_RED, Color("ffb3b8"), 12, 3))
	close_btn.add_theme_stylebox_override("hover", _box(Color("f2555f"), Color("ffd0d3"), 12, 3))
	close_btn.add_theme_stylebox_override("pressed", _box(Color("b82f38"), Color("ffb3b8"), 12, 3))
	close_btn.pressed.connect(close_shop)
	_juicy(close_btn)
	h.add_child(close_btn)

	return header


func _build_sidebar() -> Control:
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 120
	side.add_theme_constant_override("separation", 8)

	var group := ButtonGroup.new()
	for i in TABS.size():
		var t: Dictionary = TABS[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = t["title"]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(112, 92)
		b.add_theme_font_size_override("font_size", 16)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Color.WHITE)

		b.icon = _tab_icon(t["id"])
		b.expand_icon = true
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 44)

		var active := _box(C_TAB_ACTIVE, C_TAB_ACTIVE_BORDER, 14, 3)
		b.add_theme_stylebox_override("normal", _box(C_TAB, C_TAB_BORDER, 14, 2))
		b.add_theme_stylebox_override("hover", _box(Color("123775"), Color("3a82e0"), 14, 2))
		b.add_theme_stylebox_override("pressed", active)
		b.add_theme_stylebox_override("hover_pressed", active)

		b.pressed.connect(_select_tab.bind(i))
		_juicy(b)
		side.add_child(b)
		tab_buttons.append(b)

	tab_buttons[0].button_pressed = true
	return side


func _build_content() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("0a1f4a"), C_ROW_BORDER, 14, 2))

	var margin := _margin(10)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)

	page_title_label = Label.new()
	page_title_label.add_theme_font_size_override("font_size", 22)
	page_title_label.add_theme_color_override("font_color", C_NAME)
	head.add_child(page_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)

	page_subtitle_label = Label.new()
	page_subtitle_label.add_theme_font_size_override("font_size", 12)
	page_subtitle_label.add_theme_color_override("font_color", C_DESC)
	page_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	page_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_subtitle_label.custom_minimum_size.x = 150
	head.add_child(page_subtitle_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	scroll.add_child(list_box)

	return panel


func _build_footer() -> Control:
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 8)

	f.add_child(_icon_rect(_icon("coin.png", _svg_coin()), Vector2(28, 28)))

	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 22)
	coins_label.add_theme_color_override("font_color", Color("ffd23a"))
	f.add_child(coins_label)

	message_label = Label.new()
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message_label.add_theme_font_size_override("font_size", 15)
	f.add_child(message_label)

	return f


# =====================================================================
#  ABAS E LISTAS
# =====================================================================
func _select_tab(index: int) -> void:
	current_tab = index
	page_title_label.text = TABS[index]["page_title"]
	page_subtitle_label.text = TABS[index]["subtitle"]
	_populate_list(true)


func _populate_list(animate := false) -> void:
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()

	match TABS[current_tab]["id"]:
		"skins":      _populate_skins()
		"efficiency": _populate_tiers("efficiency", EFFICIENCY_TIERS, "x click")
		"fortune":    _populate_tiers("fortune", FORTUNE_TIERS, "x sorte")
		"extras":     _populate_extras()

	if animate:
		var i := 0
		for row in list_box.get_children():
			row.modulate.a = 0.0
			var tw: Tween = row.create_tween()
			tw.tween_interval(i * 0.05)
			tw.tween_property(row, "modulate:a", 1.0, 0.18)
			i += 1


func _populate_skins() -> void:
	for s in SKINS:
		var id: String = s["id"]
		var rarity: Dictionary = RARITIES[s["rarity"]]
		var btn: Button
		if id == equipped_skin:
			btn = _make_button("disabled", 0, "Equipada")
		elif id in owned_skins:
			btn = _make_button("action", 0, "Equipar")
		else:
			btn = _make_button("buy", s["price"], "Comprar")
		btn.pressed.connect(_on_skin_pressed.bind(id))
		var tex := _icon("skin_%s.png" % id, _svg_pickaxe(s["handle"], s["head"], s["edge"]))
		_add_row(tex, rarity["color"].lightened(0.3), s["name"], s["desc"],
			rarity["label"], rarity["color"], btn)


func _populate_tiers(category: String, tiers: Array, suffix: String) -> void:
	var bought: int = levels[category]
	for i in tiers.size():
		var t: Dictionary = tiers[i]
		var btn: Button
		if i < bought:
			btn = _make_button("disabled", 0, "Comprado")
		elif i == bought:
			btn = _make_button("buy", t["price"], "Comprar")
		else:
			btn = _make_button("locked", t["price"], "Bloqueado")
		btn.pressed.connect(_on_tier_pressed.bind(category, i))
		var svg := _svg_bolt(t["hex"], true) if category == "efficiency" else _svg_clover(t["hex"])
		var tex := _icon("%s_%d.png" % [category, i + 1], svg)
		_add_row(tex, Color(t["hex"]), t["name"], "%.1f%s" % [t["mult"], suffix], "", Color.WHITE, btn)


func _populate_extras() -> void:
	for e in EXTRAS:
		var id: String = e["id"]
		var btn: Button
		if id in owned_extras:
			btn = _make_button("disabled", 0, "Adquirido")
		else:
			btn = _make_button("buy", e["price"], "Comprar")
		btn.pressed.connect(_on_extra_pressed.bind(id))
		var tex := _icon("extra_%s.png" % id, _svg_extra(id, e["hex"]))
		_add_row(tex, Color(e["hex"]), e["name"], e["desc"], "", Color.WHITE, btn)


func _add_row(tex: Texture2D, frame_color: Color, title: String, desc: String,
		badge: String, badge_color: Color, btn: Button) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _box(C_ROW, C_ROW_BORDER, 12, 2, 8))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(76, 76)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _box(C_FRAME_BG, frame_color, 10, 3, 5))
	hbox.add_child(frame)
	frame.add_child(_icon_rect(tex, Vector2(60, 60)))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	hbox.add_child(info)

	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", C_NAME)
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", C_DESC)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size.x = 140
	info.add_child(desc_label)

	if badge != "":
		var b := PanelContainer.new()
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var sb := _box(badge_color, badge_color.lightened(0.35), 8, 1)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		b.add_theme_stylebox_override("panel", sb)
		var bl := Label.new()
		bl.text = badge
		bl.add_theme_font_size_override("font_size", 12)
		b.add_child(bl)
		info.add_child(b)

	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btn)
	list_box.add_child(row)


## mode: "buy" (verde, moeda + preço), "action" (azul), "disabled" (cinza), "locked" (cinza + preço)
func _make_button(mode: String, price: int, label: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(124, 68)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("8fa3c8"))

	match mode:
		"buy":
			b.add_theme_stylebox_override("normal", _box(C_GREEN, C_GREEN_DARK, 12, 3))
			b.add_theme_stylebox_override("hover", _box(C_GREEN_HOVER, C_GREEN_DARK, 12, 3))
			b.add_theme_stylebox_override("pressed", _box(C_GREEN_DARK, C_GREEN_DARK, 12, 3))
			_price_content(b, price, label, C_GREEN_DARK, Color.WHITE, false)
		"action":
			b.text = label
			b.add_theme_stylebox_override("normal", _box(C_BLUE_BTN, Color("7fb6ff"), 12, 3))
			b.add_theme_stylebox_override("hover", _box(Color("3a86ee"), Color("a5ccff"), 12, 3))
			b.add_theme_stylebox_override("pressed", _box(Color("1d55a8"), Color("7fb6ff"), 12, 3))
		"locked":
			b.disabled = true
			b.add_theme_stylebox_override("disabled", _box(C_GREY, Color("3f5380"), 12, 3))
			_price_content(b, price, label, Color("1c2842"), Color("8fa3c8"), true)
		_:
			b.text = label
			b.disabled = true
			b.add_theme_stylebox_override("disabled", _box(C_GREY, Color("3f5380"), 12, 3))

	_juicy(b)
	return b


## Monta "[moeda] preço" em cima e uma pílula com o texto embaixo (como no mockup)
func _price_content(b: Button, price: int, label: String, pill_color: Color, text_color: Color, dim: bool) -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 3)
	b.add_child(v)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 4)
	v.add_child(top)

	var coin := _icon_rect(_icon("coin.png", _svg_coin()), Vector2(22, 22))
	if dim:
		coin.modulate = Color(1, 1, 1, 0.45)
	top.add_child(coin)

	var pl := Label.new()
	pl.text = _fmt(price)
	pl.add_theme_font_size_override("font_size", 18)
	pl.add_theme_color_override("font_color", text_color)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(pl)

	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _box(pill_color, pill_color, 8, 0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", sb)
	v.add_child(pill)

	var ll := Label.new()
	ll.text = label
	ll.add_theme_font_size_override("font_size", 14)
	ll.add_theme_color_override("font_color", text_color)
	ll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(ll)


# =====================================================================
#  COMPRAS / AÇÕES
# =====================================================================
func _try_spend(amount: int) -> bool:
	if coins < amount:
		_toast("Moedas insuficientes!", Color("ff6b6b"))
		_flash_coins(Color("ff5a5a"))
		return false
	coins -= amount
	coins_changed.emit(coins)
	_update_coins_label()
	_flash_coins(Color("7dff7d"))
	return true


func _on_skin_pressed(id: String) -> void:
	var skin: Dictionary = SKINS.filter(func(s): return s["id"] == id)[0]
	if id in owned_skins:
		equipped_skin = id
		skin_equipped.emit(id)
		_toast("Equipada: " + skin["name"], Color("7dff7d"))
	else:
		if not _try_spend(skin["price"]):
			return
		owned_skins.append(id)
		equipped_skin = id
		item_purchased.emit("skin", id)
		skin_equipped.emit(id)
		_toast("Comprou e equipou: " + skin["name"], Color("7dff7d"))
	_populate_list()


func _on_tier_pressed(category: String, index: int) -> void:
	var tiers: Array = EFFICIENCY_TIERS if category == "efficiency" else FORTUNE_TIERS
	if index != levels[category]:
		return
	if not _try_spend(tiers[index]["price"]):
		return
	levels[category] += 1
	item_purchased.emit(category, str(index + 1))
	_toast("%s comprada!" % tiers[index]["name"], Color("7dff7d"))
	_populate_list()


func _on_extra_pressed(id: String) -> void:
	if id in owned_extras:
		return
	var extra: Dictionary = EXTRAS.filter(func(e): return e["id"] == id)[0]
	if not _try_spend(extra["price"]):
		return
	owned_extras.append(id)
	item_purchased.emit("extra", id)
	_toast("Adquirido: " + extra["name"], Color("7dff7d"))
	_populate_list()


func _update_coins_label() -> void:
	if coins_label:
		coins_label.text = _fmt(coins)


func _flash_coins(color: Color) -> void:
	coins_label.modulate = color
	var tw := coins_label.create_tween()
	tw.tween_property(coins_label, "modulate", Color.WHITE, 0.4)


func _toast(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.0)
	toast_tween.tween_callback(func(): message_label.text = "")
