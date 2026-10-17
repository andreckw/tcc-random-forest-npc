extends Control
class_name ShopMenu
## LOJA - Skins, Eficiência, Fortuna e Extras (visual idêntico às referências)
## Godot 4.2+. Anexe este script a um nó Control (dentro de um CanvasLayer).
## Todas as imagens ficam em res://assets/shop/ (veja a estrutura no final do arquivo).
##
## LÓGICA: qualquer nível de Eficiência/Fortuna pode ser comprado em qualquer ordem.
## O bônus ativo é o MAIOR multiplicador entre os níveis comprados (veja get_*_multiplier).

signal item_purchased(category: String, item_id: String)   # "skin", "efficiency", "fortune", "extra"
signal skin_equipped(skin_id: String)
signal extra_purchased(extra_id: String, total_owned: int)
signal coins_changed(new_amount: int)
signal closed

@export var coins: int = 1000
@export var panel_size := Vector2(574, 615)
## Escala visual do menu inteiro (0.7 = 70%).
@export_range(0.3, 2.0, 0.05) var ui_scale := 1.0
@export var play_open_animation := true
@export var assets_folder := "res://assets/shop/"

# ======================= DADOS (edite à vontade) =======================
var TABS := [
	{"id": "skins",      "title": "Skins",      "page_title": "Skins de Picareta",      "subtitle": "Deixe sua picareta com o seu estilo!", "header_icon": "header_skins"},
	{"id": "efficiency", "title": "Eficiência", "page_title": "Eficiência da Picareta", "subtitle": "Deixe sua picareta ainda mais eficiente!", "header_icon": "header_efficiency"},
	{"id": "fortune",    "title": "Fortuna",    "page_title": "Fortuna",                "subtitle": "Mais sorte para encontrar tesouros!", "header_icon": ""},
	{"id": "extras",     "title": "Extras",     "page_title": "Extras",                 "subtitle": "Itens especiais para a sua jornada!", "header_icon": ""},
]

# price 0 = já vem desbloqueada. rarity: padrao / rara / epica / lendaria
var SKINS := [
	{"id": "basica",    "name": "Picareta Básica",     "desc": "O visual clássico para os verdadeiros mineradores.", "price": 0,    "rarity": "padrao"},
	{"id": "dourada",   "name": "Picareta Dourada",    "desc": "Brilho e estilo para sua jornada.",                  "price": 500,  "rarity": "rara"},
	{"id": "cristal",   "name": "Picareta de Cristal", "desc": "Mais beleza para suas minas.",                       "price": 1500, "rarity": "epica"},
	{"id": "vulcanica", "name": "Picareta Vulcânica",  "desc": "O poder do fogo em suas mãos.",                      "price": 3000, "rarity": "lendaria"},
]
var RARITIES := {
	"padrao":   {"label": "Padrão",   "pill": "pill_padrao"},
	"rara":     {"label": "Rara",     "pill": "pill_rara"},
	"epica":    {"label": "Épica",    "pill": "pill_epica"},
	"lendaria": {"label": "Lendária", "pill": "pill_lendaria"},
}

var EFFICIENCY_TIERS := [
	{"name": "Eficiência I",   "mult": 2.0,  "price": 50},
	{"name": "Eficiência II",  "mult": 3.0,  "price": 200},
	{"name": "Eficiência III", "mult": 4.0,  "price": 500},
	{"name": "Eficiência IV",  "mult": 5.0,  "price": 1000},
	{"name": "Eficiência V",   "mult": 7.0,  "price": 5000},
	{"name": "Eficiência X",   "mult": 20.0, "price": 100000},
]
var FORTUNE_TIERS := [
	{"name": "Fortuna I",   "mult": 2.0,  "price": 100},
	{"name": "Fortuna II",  "mult": 3.0,  "price": 400},
	{"name": "Fortuna III", "mult": 4.0,  "price": 1500},
	{"name": "Fortuna IV",  "mult": 7.0,  "price": 4500},
	{"name": "Fortuna V",   "mult": 10.0, "price": 15000},
	{"name": "Fortuna X",   "mult": 20.0, "price": 100000},
]

# once = true -> compra única. false -> consumível (pode comprar várias vezes)
var EXTRAS := {
	"dynamite":           {"name": "Dinamite",            "price": 100,   "once": false},
	"tnt":                {"name": "TNT",                 "price": 500,   "once": false},
	"nuke":               {"name": "Nuke",                "price": 9999,  "once": false},
	"philosophers_stone": {"name": "Philosopher's Stone", "price": 1000,  "once": false},
	"mirror":             {"name": "Mirror",              "price": 5000,  "once": true},
	"pandoras_box":       {"name": "Pandora's Box",       "price": 5000,  "once": false},
	"pyramid_eye":        {"name": "Olho da Pirâmide",    "price": 10000, "once": false},
	"festive_cosmetics":  {"name": "FestiveCosmetics",    "price": 20000, "once": true},
}
var EXTRA_SECTIONS := [
	{"title": "BOMBAS",            "icon": "section_bombs",  "items": ["dynamite", "tnt", "nuke"]},
	{"title": "ITENS ÚTEIS",       "icon": "section_useful", "items": ["philosophers_stone", "mirror"]},
	{"title": "EVENTOS ESPECIAIS", "icon": "section_events", "items": ["pandoras_box", "pyramid_eye", "festive_cosmetics"]},
]

# Margens dos 9-patch (l, t, r, b) na escala de tela
var MARGINS := {
	"window_bg": [142, 105, 18, 85], "row_card": [22, 18, 22, 18], "icon_frame": [19, 19, 19, 19],
	"btn_green": [18, 17, 18, 19], "btn_blue": [18, 17, 18, 19], "btn_grey": [18, 17, 18, 19],
	"btn_pill": [12, 10, 12, 10], "pill_blue": [12, 10, 12, 10], "pill_grey": [12, 10, 12, 10],
	"tab_normal": [22, 20, 22, 20], "tab_hover": [22, 20, 22, 20], "tab_active": [22, 20, 22, 20],
	"pill_padrao": [12, 11, 12, 11], "pill_rara": [12, 11, 12, 11], "pill_epica": [12, 11, 12, 11],
	"pill_lendaria": [12, 11, 12, 11], "section_bar": [5, 10, 20, 10],
}

# ======================= ESTADO =======================
var owned_skins: Array = ["basica"]
var equipped_skin := "basica"
var owned_tiers := {"efficiency": [], "fortune": []}   # índices dos níveis comprados
var extras_inventory := {}                              # id -> quantidade
var current_tab := 0

# ======================= UI =======================
var window: PanelContainer
var tab_group := ButtonGroup.new()
var tab_buttons: Array[Button] = []
var page_icon: TextureRect
var page_title_label: Label
var page_subtitle_label: Label
var list_box: VBoxContainer
var coins_label: Label
var message_label: Label
var toast_tween: Tween
var _tex_cache := {}
var _font_bold: Font
var _font_med: Font

const C_TEXT := Color.WHITE
const C_SUB := Color("cfe3ff")
const C_LINE := Color("1e6fe0")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_fonts()
	_build_ui()
	_select_tab(0)
	_update_coins_label()
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
	return _best_mult(EFFICIENCY_TIERS, owned_tiers["efficiency"])

func get_fortune_multiplier() -> float:
	return _best_mult(FORTUNE_TIERS, owned_tiers["fortune"])

func get_equipped_skin() -> String:
	return equipped_skin

func get_extra_count(extra_id: String) -> int:
	return int(extras_inventory.get(extra_id, 0))

func has_extra(extra_id: String) -> bool:
	return get_extra_count(extra_id) > 0

## Consome 1 unidade de um extra (ex: ao plantar uma dinamite). Retorna false se não tiver.
func use_extra(extra_id: String) -> bool:
	if get_extra_count(extra_id) <= 0:
		return false
	extras_inventory[extra_id] = get_extra_count(extra_id) - 1
	if list_box != null:
		_populate_list()
	return true

func open_shop() -> void:
	show()
	_populate_list(true)
	_play_open()

func close_shop() -> void:
	hide()
	closed.emit()

func get_save_data() -> Dictionary:
	return {"coins": coins, "owned_skins": owned_skins, "equipped_skin": equipped_skin,
		"owned_tiers": owned_tiers, "extras_inventory": extras_inventory}

func load_save_data(d: Dictionary) -> void:
	coins = d.get("coins", coins)
	owned_skins = d.get("owned_skins", owned_skins)
	equipped_skin = d.get("equipped_skin", equipped_skin)
	owned_tiers = d.get("owned_tiers", owned_tiers)
	extras_inventory = d.get("extras_inventory", extras_inventory)
	if list_box != null:
		_update_coins_label()
		_populate_list()

func _best_mult(tiers: Array, owned: Array) -> float:
	var best := 1.0
	for i in owned:
		best = maxf(best, float(tiers[int(i)]["mult"]))
	return best


# =====================================================================
#  RECURSOS (texturas, estilos, fontes)
# =====================================================================
func _tex(rel: String) -> Texture2D:
	if rel == "":
		return null
	if _tex_cache.has(rel):
		return _tex_cache[rel]
	var path := assets_folder + rel
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	if t == null:
		push_warning("ShopMenu: imagem não encontrada: " + path)
	_tex_cache[rel] = t
	return t

## StyleBox 9-patch a partir de ui/<name>.png. content = margens internas (l, t, r, b).
func _nine(name: String, content := Vector4(0, 0, 0, 0)) -> StyleBox:
	var t := _tex("ui/%s.png" % name)
	var sb_flat := StyleBoxFlat.new()
	if t == null:  # plano B se a imagem não existir
		sb_flat.bg_color = Color("0c2554")
		sb_flat.border_color = Color("2a6fd1")
		sb_flat.set_border_width_all(2)
		sb_flat.set_corner_radius_all(8)
		sb_flat.content_margin_left = content.x
		sb_flat.content_margin_top = content.y
		sb_flat.content_margin_right = content.z
		sb_flat.content_margin_bottom = content.w
		return sb_flat
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var m: Array = MARGINS[name]
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb

func _tinted(sb: StyleBox, c: Color) -> StyleBox:
	var d: StyleBox = sb.duplicate() as StyleBox
	if d is StyleBoxTexture:
		(d as StyleBoxTexture).modulate_color = c
	return d

func _load_fonts() -> void:
	var fb := assets_folder + "fonts/Poppins-Bold.ttf"
	var fm := assets_folder + "fonts/Poppins-Medium.ttf"
	if ResourceLoader.exists(fb):
		_font_bold = load(fb)
	else:
		var fv := FontVariation.new()
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = 0.7
		_font_bold = fv
	_font_med = load(fm) if ResourceLoader.exists(fm) else ThemeDB.fallback_font

func _label(text: String, size: int, color := C_TEXT, bold := true, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font_bold if bold else _font_med)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color("0a1f4d"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _img(rel: String, size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _tex(rel)
	tr.custom_minimum_size = size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _margin(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	return m

func _ignore_mouse(n: Node) -> void:
	if n is Control and not (n is BaseButton):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)

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


# =====================================================================
#  ANIMAÇÕES
# =====================================================================
func _play_open() -> void:
	await get_tree().process_frame
	if window == null:
		return
	window.pivot_offset = window.size / 2.0
	var target := Vector2.ONE * ui_scale
	if not play_open_animation:
		window.scale = target
		return
	window.scale = target * 0.92
	window.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(window, "scale", target, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(window, "modulate:a", 1.0, 0.15)

func _juicy(b: BaseButton) -> void:
	b.resized.connect(_on_btn_resized.bind(b))
	b.mouse_entered.connect(_on_btn_hover.bind(b, true))
	b.mouse_exited.connect(_on_btn_hover.bind(b, false))
	b.button_down.connect(_on_btn_down.bind(b))
	b.button_up.connect(_on_btn_up.bind(b))

func _on_btn_resized(b: BaseButton) -> void:
	b.pivot_offset = b.size / 2.0

func _on_btn_hover(b: BaseButton, entered: bool) -> void:
	_tween_scale(b, 1.05 if (entered and not b.disabled) else 1.0)

func _on_btn_down(b: BaseButton) -> void:
	_tween_scale(b, 0.95)

func _on_btn_up(b: BaseButton) -> void:
	_tween_scale(b, 1.05 if (b.is_hovered() and not b.disabled) else 1.0)

func _tween_scale(n: Control, s: float) -> void:
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(s, s), 0.08)


# =====================================================================
#  CONSTRUÇÃO DA INTERFACE
# =====================================================================
func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	window = PanelContainer.new()
	window.custom_minimum_size = panel_size
	window.add_theme_stylebox_override("panel", _nine("window_bg", Vector4(8, 8, 8, 4)))
	center.add_child(window)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	window.add_child(root)

	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	root.add_child(body)
	body.add_child(_build_sidebar())
	body.add_child(_build_content())


func _build_header() -> Control:
	var m := _margin(16, 0, 12, 0)
	m.custom_minimum_size.y = 80
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)

	h.add_child(_img("icons/header/shop_icon.png", Vector2(70, 62)))
	h.add_child(_img("icons/header/title_loja.png", Vector2(100, 40)))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(spacer)

	var close_btn := TextureButton.new()
	close_btn.texture_normal = _tex("icons/header/close_btn.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.custom_minimum_size = Vector2(46, 46)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close_shop)
	_juicy(close_btn)
	h.add_child(close_btn)
	return m


func _build_sidebar() -> Control:
	var m := _margin(2, 12, 0, 0)
	m.custom_minimum_size.x = 123
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	for i in TABS.size():
		var b := _make_tab(i)
		v.add_child(b)
		tab_buttons.append(b)
	tab_buttons[0].button_pressed = true
	return m


func _make_tab(i: int) -> Button:
	var t: Dictionary = TABS[i]
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = tab_group
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(112, 66)
	b.add_theme_stylebox_override("normal", _nine("tab_normal"))
	b.add_theme_stylebox_override("hover", _nine("tab_hover"))
	b.add_theme_stylebox_override("pressed", _nine("tab_active"))
	b.add_theme_stylebox_override("hover_pressed", _nine("tab_active"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var icon := _img("icons/tabs/tab_%s.png" % t["id"], Vector2(44, 44))
	icon.position = Vector2(10, 4)
	icon.size = Vector2(44, 44)
	b.add_child(icon)

	var lm := _margin(0, 0, 9, 8)
	lm.set_anchors_preset(Control.PRESET_FULL_RECT)
	lm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := _label(t["title"], 13, C_TEXT, true, 3)
	lab.size_flags_horizontal = Control.SIZE_SHRINK_END
	lab.size_flags_vertical = Control.SIZE_SHRINK_END
	lm.add_child(lab)
	b.add_child(lm)

	b.pressed.connect(_select_tab.bind(i))
	_juicy(b)
	return b


func _build_content() -> Control:
	var m := _margin(14, 10, 6, 0)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)

	# Cabeçalho da página
	var head := HBoxContainer.new()
	head.custom_minimum_size.y = 36
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	page_icon = _img("", Vector2(28, 28))
	head.add_child(page_icon)
	page_title_label = _label("", 19)
	head.add_child(page_title_label)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	page_subtitle_label = _label("", 11, C_SUB, false)
	page_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	page_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_subtitle_label.custom_minimum_size.x = 120
	head.add_child(page_subtitle_label)

	# Lista rolável
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 7)
	scroll.add_child(list_box)

	v.add_child(_build_footer())
	return m


func _build_footer() -> Control:
	var f := HBoxContainer.new()
	f.custom_minimum_size.y = 54
	f.add_theme_constant_override("separation", 6)

	var left := HBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 6)
	left.add_child(_img("icons/header/cart.png", Vector2(26, 22)))
	left.add_child(_line(34))
	left.add_child(_img("ui/diamond.png", Vector2(10, 10)))
	f.add_child(left)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 0)
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 5)
	crow.add_child(_img("icons/header/coin.png", Vector2(20, 20)))
	coins_label = _label("", 16, Color("ffd23a"), true, 2)
	crow.add_child(coins_label)
	center.add_child(crow)
	message_label = _label("", 11, C_TEXT, false)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(message_label)
	f.add_child(center)

	var right := HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 6)
	right.add_child(_img("ui/diamond.png", Vector2(10, 10)))
	right.add_child(_line(34))
	f.add_child(right)
	return f


func _line(width: int) -> ColorRect:
	var l := ColorRect.new()
	l.color = C_LINE
	l.custom_minimum_size = Vector2(width, 2)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# =====================================================================
#  ABAS E LISTAS
# =====================================================================
func _select_tab(index: int) -> void:
	current_tab = index
	var t: Dictionary = TABS[index]
	page_title_label.text = t["page_title"]
	page_subtitle_label.text = t["subtitle"]
	var hi: String = t["header_icon"]
	page_icon.visible = hi != ""
	if hi != "":
		page_icon.texture = _tex("icons/header/%s.png" % hi)
	_populate_list(true)


func _populate_list(animate := false) -> void:
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()

	match TABS[current_tab]["id"]:
		"skins":      _populate_skins()
		"efficiency": _populate_tiers("efficiency", EFFICIENCY_TIERS, "x click", Color.WHITE)
		"fortune":    _populate_tiers("fortune", FORTUNE_TIERS, "x drop", Color("a9d6ff"))
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
		var btn: Button
		if id == equipped_skin:
			btn = _make_button("disabled", 0, "Equipada")
		elif id in owned_skins:
			btn = _make_button("action", 0, "Equipar")
		else:
			btn = _make_button("buy", s["price"], "Comprar")
		btn.pressed.connect(_on_skin_pressed.bind(id))
		var rar: Dictionary = RARITIES[s["rarity"]]
		var icon := _framed_icon("icons/skins/skin_%s.png" % id, Vector2(88, 88), Vector2(66, 66))
		_add_row(icon, s["name"], s["desc"], C_SUB, rar, btn)


func _populate_tiers(category: String, tiers: Array, suffix: String, sub_color: Color) -> void:
	var owned: Array = owned_tiers[category]
	for i in tiers.size():
		var t: Dictionary = tiers[i]
		var btn: Button
		if i in owned:
			btn = _make_button("disabled", 0, "Comprado")
		else:
			btn = _make_button("buy", t["price"], "Comprar")
		btn.pressed.connect(_on_tier_pressed.bind(category, i))
		var tex := _tex("tiles/%s_%d.png" % [category, i + 1])
		var icon := TextureRect.new()
		icon.texture = tex
		if tex:
			icon.custom_minimum_size = tex.get_size() * 0.5
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_add_row(icon, t["name"], "%.1f%s" % [t["mult"], suffix], sub_color, {}, btn)


func _populate_extras() -> void:
	for sec in EXTRA_SECTIONS:
		list_box.add_child(_section_header(sec["title"], sec["icon"]))
		for id in sec["items"]:
			var e: Dictionary = EXTRAS[id]
			var owned := get_extra_count(id)
			var btn: Button
			if e["once"] and owned > 0:
				btn = _make_button("disabled", 0, "Comprado")
			else:
				btn = _make_button("buy", e["price"], "Comprar")
			btn.pressed.connect(_on_extra_pressed.bind(id))
			var icon := _framed_icon("icons/extras/extra_%s.png" % id, Vector2(86, 56), Vector2(44, 44))
			var sub := ""
			if not e["once"] and owned > 0:
				sub = "Você tem: %d" % owned
			_add_row(icon, e["name"], sub, C_SUB, {}, btn)


func _section_header(title: String, icon_name: String) -> Control:
	var h := HBoxContainer.new()
	h.custom_minimum_size.y = 36
	h.add_theme_constant_override("separation", -6)
	h.add_child(_img("icons/sections/%s.png" % icon_name, Vector2(36, 36)))
	var bar := PanelContainer.new()
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("panel", _nine("section_bar", Vector4(12, 3, 24, 3)))
	bar.add_child(_label(title, 15, C_TEXT, true, 3))
	h.add_child(bar)
	var tail := HBoxContainer.new()
	tail.add_theme_constant_override("separation", 0)
	tail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tail.add_child(_line(90))
	tail.add_child(_img("ui/diamond.png", Vector2(10, 10)))
	h.add_child(tail)
	return h


## Moldura azul arredondada com o ícone dentro (skins e extras)
func _framed_icon(rel: String, frame_size: Vector2, icon_size: Vector2) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = frame_size
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", _nine("icon_frame", Vector4(8, 8, 8, 8)))
	var ic := _img(rel, icon_size)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(ic)
	return p


## Linha (card) da lista: [ícone] [nome / descrição / selo] [botão]
func _add_row(icon: Control, title: String, desc: String, desc_color: Color, rarity: Dictionary, btn: Button) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _nine("row_card", Vector4(10, 8, 10, 8)))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)
	hbox.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 2)
	hbox.add_child(info)

	var name_l := _label(title, 16)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size.x = 90
	info.add_child(name_l)

	if desc != "":
		var d := _label(desc, 11 if not rarity.is_empty() else 14, desc_color, false)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 90
		info.add_child(d)

	if not rarity.is_empty():
		info.add_child(_rarity_pill(rarity))

	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(btn)
	list_box.add_child(row)


func _rarity_pill(rarity: Dictionary) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pill.add_theme_stylebox_override("panel", _nine(rarity["pill"], Vector4(10, 1, 10, 2)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	pill.add_child(h)
	if rarity["pill"] == "pill_padrao":
		h.add_child(_img("icons/header/check.png", Vector2(13, 13)))
	h.add_child(_label(rarity["label"], 11, C_TEXT, false))
	return pill


## mode: "buy" (verde: moeda + preço + Comprar), "action" (azul), "disabled" (cinza)
func _make_button(mode: String, price: int, label: String) -> Button:
	var btn_style := "btn_green"
	var pill_style := "btn_pill"
	match mode:
		"action":
			btn_style = "btn_blue"
			pill_style = "pill_blue"
		"disabled":
			btn_style = "btn_grey"
			pill_style = "pill_grey"

	var b := Button.new()
	b.custom_minimum_size = Vector2(108, 62)
	b.focus_mode = Control.FOCUS_NONE
	var normal := _nine(btn_style)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", _tinted(normal, Color(1.12, 1.12, 1.12)))
	b.add_theme_stylebox_override("pressed", _tinted(normal, Color(0.82, 0.82, 0.82)))
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = (mode == "disabled")

	var m := _margin(7, 5, 7, 7)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	m.add_child(v)

	if mode == "buy":
		var top := HBoxContainer.new()
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		top.size_flags_vertical = Control.SIZE_EXPAND_FILL
		top.add_theme_constant_override("separation", 4)
		top.add_child(_img("icons/header/coin.png", Vector2(22, 22)))
		top.add_child(_label(_fmt(price), 15, C_TEXT, true, 2))
		v.add_child(top)

	var pill := PanelContainer.new()
	pill.custom_minimum_size.y = 22 if mode == "buy" else 30
	pill.add_theme_stylebox_override("panel", _nine(pill_style, Vector4(4, 0, 4, 1)))
	var pl := _label(label, 12)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(pl)
	v.add_child(pill)

	_ignore_mouse(m)
	_juicy(b)
	return b


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
	var owned: Array = owned_tiers[category]
	if index in owned:
		return
	if not _try_spend(tiers[index]["price"]):
		return
	owned.append(index)
	item_purchased.emit(category, str(index + 1))
	_toast("%s comprada!" % tiers[index]["name"], Color("7dff7d"))
	_populate_list()


func _on_extra_pressed(id: String) -> void:
	var e: Dictionary = EXTRAS[id]
	if e["once"] and get_extra_count(id) > 0:
		return
	if not _try_spend(e["price"]):
		return
	extras_inventory[id] = get_extra_count(id) + 1
	item_purchased.emit("extra", id)
	extra_purchased.emit(id, get_extra_count(id))
	_toast("Adquirido: " + e["name"], Color("7dff7d"))
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

# =====================================================================
#  ESTRUTURA DE PASTAS ESPERADA (res://assets/shop/)
#    ui/      -> window_bg, row_card, icon_frame, btn_*, pill_*, tab_*, section_bar, diamond
#    tiles/   -> efficiency_1..6, fortune_1..6   (moldura + ícone brilhante)
#    icons/   -> skins/, efficiency/, fortune/, extras/, tabs/, sections/, header/
#    fonts/   -> Poppins-Bold.ttf, Poppins-Medium.ttf
# =====================================================================
