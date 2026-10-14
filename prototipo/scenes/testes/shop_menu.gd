extends Control
class_name ShopMenu
## Loja estilizada: Skins, Eficiência, Fortuna e Extras.
## Requer Godot 4.2+.
## Uso: crie um Control (dentro de um CanvasLayer), anexe este script e rode.
## A interface inteira é montada por código.
##
## ÍCONES (opcional): coloque PNGs em res://assets/shop/ com estes nomes:
##   abas:        tab_skins.png, tab_efficiency.png, tab_fortune.png, tab_extras.png
##   topo:        shop_icon.png
##   skins:       skin_basica.png, skin_dourada.png, skin_cristal.png, skin_vulcanica.png
##   eficiência:  efficiency_1.png ... efficiency_6.png (na ordem da lista)
##   fortuna:     fortune_1.png ... fortune_4.png
##   extras:      extra_<id>.png (ex: extra_mochila.png)
## Se o arquivo não existir, aparece uma letra no lugar (não dá erro).

signal item_purchased(category: String, item_id: String)
signal skin_equipped(skin_id: String)
signal coins_changed(new_amount: int)
signal closed

@export var panel_size := Vector2(560, 720)
@export var coins: int = 1000
@export var icons_folder := "res://assets/shop/"

# ======================= CORES DO TEMA =======================
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

# ======================= DADOS DA LOJA =======================
var TABS := [
	{"id": "skins",      "title": "Skins",      "subtitle": "Deixe sua picareta com o seu estilo!",       "page_title": "Skins de Picareta",      "icon": "tab_skins.png"},
	{"id": "efficiency", "title": "Eficiência", "subtitle": "Deixe sua picareta ainda mais eficiente!",   "page_title": "Eficiência da Picareta", "icon": "tab_efficiency.png"},
	{"id": "fortune",    "title": "Fortuna",    "subtitle": "Mais sorte para encontrar tesouros!",        "page_title": "Fortuna",                "icon": "tab_fortune.png"},
	{"id": "extras",     "title": "Extras",     "subtitle": "Itens especiais para a sua jornada!",        "page_title": "Extras",                 "icon": "tab_extras.png"},
]

# rarity: padrao / rara / epica / lendaria
var SKINS := [
	{"id": "basica",    "name": "Picareta Básica",    "desc": "O visual clássico para os verdadeiros mineradores.", "price": 0,    "rarity": "padrao"},
	{"id": "dourada",   "name": "Picareta Dourada",   "desc": "Brilho e estilo para sua jornada.",                  "price": 500,  "rarity": "rara"},
	{"id": "cristal",   "name": "Picareta de Cristal","desc": "Mais beleza para suas minas.",                       "price": 1500, "rarity": "epica"},
	{"id": "vulcanica", "name": "Picareta Vulcânica", "desc": "O poder do fogo em suas mãos.",                      "price": 3000, "rarity": "lendaria"},
]

var RARITIES := {
	"padrao":   {"label": "Padrão",   "color": Color("2b3b5c")},
	"rara":     {"label": "Rara",     "color": Color("1f5fd6")},
	"epica":    {"label": "Épica",    "color": Color("7a2fd0")},
	"lendaria": {"label": "Lendária", "color": Color("c4701a")},
}

# Níveis comprados em ordem (precisa comprar o I antes do II, etc.)
var EFFICIENCY_TIERS := [
	{"name": "Eficiência I",   "mult": 2.0,  "price": 50,     "color": Color("3a8bff")},
	{"name": "Eficiência II",  "mult": 3.0,  "price": 200,    "color": Color("3fd04a")},
	{"name": "Eficiência III", "mult": 4.0,  "price": 500,    "color": Color("38b6ff")},
	{"name": "Eficiência IV",  "mult": 5.0,  "price": 1000,   "color": Color("b455ff")},
	{"name": "Eficiência V",   "mult": 7.0,  "price": 5000,   "color": Color("ff9a1f")},
	{"name": "Eficiência X",   "mult": 20.0, "price": 100000, "color": Color("ff3b3b")},
]

# EXEMPLO (ajuste como quiser)
var FORTUNE_TIERS := [
	{"name": "Fortuna I",   "mult": 1.2, "price": 100,   "color": Color("3fd04a")},
	{"name": "Fortuna II",  "mult": 1.5, "price": 400,   "color": Color("38b6ff")},
	{"name": "Fortuna III", "mult": 2.0, "price": 1500,  "color": Color("b455ff")},
	{"name": "Fortuna IV",  "mult": 3.0, "price": 6000,  "color": Color("ff9a1f")},
]

# EXEMPLO (ajuste como quiser)
var EXTRAS := [
	{"id": "mochila",  "name": "Mochila Maior",  "desc": "Carrega mais minérios.",         "price": 250, "color": Color("3a8bff")},
	{"id": "lanterna", "name": "Lanterna",       "desc": "Enxergue melhor nas cavernas.",  "price": 150, "color": Color("ffd23a")},
	{"id": "ima",      "name": "Ímã de Minério", "desc": "Atrai drops próximos.",          "price": 400, "color": Color("b455ff")},
	{"id": "botas",    "name": "Botas Rápidas",  "desc": "Move-se mais rápido.",           "price": 300, "color": Color("3fd04a")},
]

# ======================= ESTADO =======================
var owned_skins: Array = ["basica"]
var equipped_skin := "basica"
var levels := {"efficiency": 0, "fortune": 0} # quantos níveis já foram comprados
var owned_extras: Array = []
var current_tab := 0

# ======================= REFERÊNCIAS DE UI =======================
var tab_buttons: Array[Button] = []
var page_title_label: Label
var page_subtitle_label: Label
var list_box: VBoxContainer
var coins_label: Label
var message_label: Label
var toast_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_select_tab(0)
	_update_coins_label()


# =====================================================================
#  API PÚBLICA
# =====================================================================
func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	_update_coins_label()
	if is_inside_tree() and list_box != null:
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
	_populate_list()

func close_shop() -> void:
	hide()
	closed.emit()

## Para salvar o progresso (use com FileAccess/JSON ou ConfigFile)
func get_save_data() -> Dictionary:
	return {
		"coins": coins,
		"owned_skins": owned_skins,
		"equipped_skin": equipped_skin,
		"levels": levels,
		"owned_extras": owned_extras,
	}

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
#  HELPERS DE ESTILO
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

func _tex(file_name: String) -> Texture2D:
	var path := icons_folder + file_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

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

	var window := PanelContainer.new()
	window.custom_minimum_size = panel_size
	window.add_theme_stylebox_override("panel", _box(C_BG, C_BORDER, 18, 4))
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

	var icon_tex := _tex("shop_icon.png")
	if icon_tex:
		var ti := TextureRect.new()
		ti.texture = icon_tex
		ti.custom_minimum_size = Vector2(56, 56)
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(ti)

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
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)

		var tex := _tex(t["icon"])
		if tex:
			b.icon = tex
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
	f.add_theme_constant_override("separation", 12)

	coins_label = Label.new()
	coins_label.add_theme_font_size_override("font_size", 20)
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
	_populate_list()


func _populate_list() -> void:
	for c in list_box.get_children():
		list_box.remove_child(c)
		c.queue_free()

	match TABS[current_tab]["id"]:
		"skins":      _populate_skins()
		"efficiency": _populate_tiers("efficiency", EFFICIENCY_TIERS, "x click", "efficiency_")
		"fortune":    _populate_tiers("fortune", FORTUNE_TIERS, "x sorte", "fortune_")
		"extras":     _populate_extras()


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
		_add_row("skin_%s.png" % id, s["name"].substr(0, 1), rarity["color"].lightened(0.3),
			s["name"], s["desc"], rarity["label"], rarity["color"], btn)


func _populate_tiers(category: String, tiers: Array, suffix: String, icon_prefix: String) -> void:
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
		_add_row("%s%d.png" % [icon_prefix, i + 1], _roman(i), t["color"],
			t["name"], "%.1f%s" % [t["mult"], suffix], "", Color.WHITE, btn)


func _populate_extras() -> void:
	for e in EXTRAS:
		var id: String = e["id"]
		var btn: Button
		if id in owned_extras:
			btn = _make_button("disabled", 0, "Adquirido")
		else:
			btn = _make_button("buy", e["price"], "Comprar")
		btn.pressed.connect(_on_extra_pressed.bind(id))
		_add_row("extra_%s.png" % id, e["name"].substr(0, 1), e["color"],
			e["name"], e["desc"], "", Color.WHITE, btn)


func _roman(i: int) -> String:
	var romans := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return romans[i] if i < romans.size() else str(i + 1)


## Cria uma linha (card) da lista
func _add_row(icon_file: String, fallback: String, frame_color: Color, title: String,
		desc: String, badge: String, badge_color: Color, btn: Button) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _box(C_ROW, C_ROW_BORDER, 12, 2, 8))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	row.add_child(hbox)

	# Moldura do ícone
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(76, 76)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", _box(C_FRAME_BG, frame_color, 10, 3, 4))
	hbox.add_child(frame)

	var tex := _tex(icon_file)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(tr)
	else:
		var l := Label.new()
		l.text = fallback
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", frame_color)
		frame.add_child(l)

	# Texto
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


## mode: "buy" (verde com preço), "action" (azul), "disabled" (cinza), "locked" (cinza com preço)
func _make_button(mode: String, price: int, label: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 66)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("8fa3c8"))

	match mode:
		"buy":
			b.text = "$ %s\n%s" % [_fmt(price), label]
			b.add_theme_stylebox_override("normal", _box(C_GREEN, C_GREEN_DARK, 12, 3))
			b.add_theme_stylebox_override("hover", _box(C_GREEN_HOVER, C_GREEN_DARK, 12, 3))
			b.add_theme_stylebox_override("pressed", _box(C_GREEN_DARK, C_GREEN_DARK, 12, 3))
		"action":
			b.text = label
			b.add_theme_stylebox_override("normal", _box(C_BLUE_BTN, Color("7fb6ff"), 12, 3))
			b.add_theme_stylebox_override("hover", _box(Color("3a86ee"), Color("a5ccff"), 12, 3))
			b.add_theme_stylebox_override("pressed", _box(Color("1d55a8"), Color("7fb6ff"), 12, 3))
		"locked":
			b.text = "$ %s\n%s" % [_fmt(price), label]
			b.disabled = true
			b.add_theme_stylebox_override("disabled", _box(C_GREY, Color("3f5380"), 12, 3))
		_: # disabled
			b.text = label
			b.disabled = true
			b.add_theme_stylebox_override("disabled", _box(C_GREY, Color("3f5380"), 12, 3))
	return b


# =====================================================================
#  COMPRAS / AÇÕES
# =====================================================================
func _try_spend(amount: int) -> bool:
	if coins < amount:
		_toast("Moedas insuficientes!", Color("ff6b6b"))
		return false
	coins -= amount
	coins_changed.emit(coins)
	_update_coins_label()
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
		coins_label.text = "$ " + _fmt(coins)


func _toast(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.0)
	toast_tween.tween_callback(func(): message_label.text = "")
