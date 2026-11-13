extends Control
class_name NpcMenu
## LOJA DE NPCs - Mineradores, Cenário, Especiais e Secretos. Godot 4.2+
## Anexe este script a um nó Control (dentro de um CanvasLayer).
## Imagens em res://assets/npc/ (estrutura no final do arquivo).
##
## DINHEIRO: usa o seu Autoload (script com `dinheiro` e `adicionar_dinheiro()`).
## Deixe `money_autoload` vazio para detectar sozinho, ou escreva o nome do Autoload.
##
## USO NO JOGO: ligue o sinal `npc_purchased(npc_id, total)` para criar o NPC na cena.
## Se um NPC sair do jogo, chame `release_npc(npc_id)` para liberar uma vaga do limite.

signal npc_purchased(npc_id: String, total_owned: int)
signal closed

## Nome do Autoload de dinheiro (Projeto > Configurações > Autoload). Vazio = detecta sozinho.
@export var money_autoload := ""
@export var panel_size := Vector2(589, 700)
## Escala visual do menu inteiro (0.7 = 70%).
@export_range(0.3, 2.0, 0.05) var ui_scale := 1.0
@export var play_open_animation := true
## Marque para o menu já começar fechado (abra com open_menu()).
@export var start_hidden := false
@export var assets_folder := "res://assets/npc/"

# ======================= DADOS (edite à vontade) =======================
# view: "miner" e "scenery" = lista de NPCs (NPCS[id]); "soon" = tela "Em breve".
var TABS := [
	{"id": "miners",  "title": "MINERADORES", "icon": "icons/tab_miners.png",  "width": 152, "view": "miner"},
	{"id": "scenery", "title": "CENÁRIO",     "icon": "icons/tab_scenery.png", "width": 130, "view": "scenery"},
	{"id": "special", "title": "ESPECIAIS",   "icon": "icons/tab_special.png", "width": 131, "view": "soon"},
	{"id": "secret",  "title": "SECRETOS",    "icon": "icons/tab_secret.png",  "width": 128, "view": "soon"},
]

# id (único) | name | desc | price | limit (máx. que o jogador pode ter) | portrait (arquivo em portraits/)
# Mineradores: perf e exp de 0 a 10 (use -1 para "?"); bonus (opcional) mostra a faixa dourada.
var NPCS := {
	"miners": [
		{"id": "minerador_iniciante",    "name": "Minerador Iniciante",    "desc": "Trabalhador inexperiente, recém chegado a mineração.",                   "price": 100,   "limit": 10, "portrait": "minerador_iniciante",    "perf": 4,  "exp": 4},
		{"id": "minerador_auxiliar",     "name": "Minerador Auxiliar",     "desc": "Trabalhador prestativo, ágil e versátil.",                               "price": 1000,  "limit": 5,  "portrait": "minerador_auxiliar",     "perf": 6,  "exp": 6},
		{"id": "minerador_experiente",   "name": "Minerador Experiente",   "desc": "Trabalhador experiente, eficiente e resistente.",                        "price": 3000,  "limit": 5,  "portrait": "minerador_experiente",   "perf": 8,  "exp": 8},
		{"id": "minerador_explorador",   "name": "Minerador Explorador",   "desc": "Trabalhador aventureiro, observador e especializado em explorar as minas.", "price": 5000, "limit": 3,  "portrait": "minerador_explorador",   "perf": -1, "exp": -1},
		{"id": "minerador_especialista", "name": "Minerador Especialista", "desc": "Especialista em mineração, altamente eficiente.",                        "price": 10000, "limit": 5,  "portrait": "minerador_especialista", "perf": 10, "exp": 10},
		{"id": "supervisor_mina",        "name": "Supervisor da Mina",     "desc": "Observa os trabalhadores e acompanha as atividades.",                    "price": 1, "limit": 1,  "portrait": "supervisor_mina",        "perf": -1, "exp": -1, "bonus": "Bônus de dinheiro e velocidade."},
	],
	"scenery": [
		{"id": "campones",    "name": "Camponês",    "desc": "Trabalhador humilde e dedicado, acostumado à vida simples do campo.",       "price": 100,  "limit": 5, "portrait": "campones"},
		{"id": "comerciante", "name": "Comerciante", "desc": "Negociante experiente e persuasivo, sempre em busca de boas oportunidades.", "price": 200,  "limit": 5, "portrait": "comerciante"},
		{"id": "professor",   "name": "Professor",   "desc": "Intelectual curioso e sábio, dedicado ao estudo e à descoberta de novos conhecimentos.", "price": 1000, "limit": 1, "portrait": "professor"},
		{"id": "cavaleiro",   "name": "Cavaleiro",   "desc": "Guerreiro honrado e disciplinado, conhecido por sua coragem e lealdade.",   "price": 500,  "limit": 2, "portrait": "cavaleiro"},
		{"id": "arqueiro",    "name": "Arqueiro",    "desc": "Habilidoso, ágil e preciso, especialista em acertar seus alvos à distância.", "price": 500,  "limit": 2, "portrait": "arqueiro"},
		{"id": "mago",        "name": "Mago",        "desc": "Figura misteriosa e enigmática, conhecedora de antigas artes e segredos ocultos.", "price": 2456, "limit": 1, "portrait": "mago"},
	],
}

# Margens dos 9-patch (l, t, r, b) na escala de tela. Só mude se trocar a imagem.
var MARGINS := {
	"window_bg": [142, 142, 120, 50], "card_miner": [20, 20, 20, 20], "card_scenery": [22, 32, 22, 22],
	"stat_box": [10, 10, 10, 10], "desc_box": [11, 11, 11, 11], "desc_scenery": [13, 13, 13, 13],
	"price_box": [11, 11, 11, 11], "bonus_banner": [12, 11, 12, 11],
	"btn_buy": [15, 12, 15, 12], "btn_grey": [15, 12, 15, 12],
	"tab_active": [20, 20, 20, 20], "tab_normal": [20, 20, 20, 20], "tab_hover": [20, 20, 20, 20],
}

const C_TEXT := Color.WHITE
const C_SOFT := Color("cfe3ff")
const C_GOLD := Color("ffd23a")
const C_PERF := Color("ffb020")
const C_EXP := Color("1aa6ff")
const C_BAR_OFF := Color("17305e")
const CARD_W := 182

# ======================= ESTADO =======================
var npc_counts := {}          # id -> quantos o jogador possui
var current_tab := 0

# ======================= UI =======================
var window: PanelContainer
var tab_group := ButtonGroup.new()
var grid: GridContainer
var coins_label: Label
var message_label: Label
var toast_tween: Tween
var _money: Node
var _last_coins := -1
var _tex_cache := {}
var _font_bold: Font
var _font_med: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_money = _find_money()
	_font_bold = _load_font("Poppins-Bold.ttf")
	_font_med = _load_font("Poppins-Medium.ttf")
	_build_ui()
	_select_tab(0)
	_update_coins_label()
	_play_open()
	if start_hidden:
		hide()


func _process(_delta: float) -> void:
	# Atualiza o saldo quando o jogador ganha dinheiro com o menu aberto
	if visible and get_coins() != _last_coins:
		_update_coins_label()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


# =====================================================================
#  API PÚBLICA
# =====================================================================
func open_menu() -> void:
	show()
	_update_coins_label()
	_populate_cards(true)
	_play_open()

func close_menu() -> void:
	hide()
	closed.emit()

func get_coins() -> int:
	return int(_money.dinheiro) if _money else 0

func get_npc_count(npc_id: String) -> int:
	return int(npc_counts.get(npc_id, 0))

## Libera uma vaga do limite (use quando um NPC sair do jogo).
func release_npc(npc_id: String) -> void:
	npc_counts[npc_id] = maxi(0, get_npc_count(npc_id) - 1)
	_populate_cards()

func get_save_data() -> Dictionary:
	return {"npc_counts": npc_counts}

func load_save_data(d: Dictionary) -> void:
	npc_counts = d.get("npc_counts", npc_counts)
	
	if npc_counts.get("supervisor_mina", 0) > 0:
		ativar_bonus_supervisor()
	
	if grid != null:
		_populate_cards()


# =====================================================================
#  DINHEIRO (usa o Autoload do jogo)
# =====================================================================
func _find_money() -> Node:
	if money_autoload != "":
		var n := get_node_or_null("/root/" + money_autoload)
		if n == null:
			push_error("NpcMenu: Autoload '%s' não encontrado." % money_autoload)
		return n
	for n in get_tree().root.get_children():
		if "dinheiro" in n and n.has_method("adicionar_dinheiro"):
			return n
	push_error("NpcMenu: nenhum Autoload com 'dinheiro' e 'adicionar_dinheiro()' foi encontrado.")
	return null

func _try_spend(amount: int) -> bool:
	if get_coins() < amount:
		_toast("Moedas insuficientes!", Color("ff6b6b"))
		_flash_coins(Color("ff5a5a"))
		return false
	_money.adicionar_dinheiro(-amount)
	_update_coins_label()
	_flash_coins(Color("7dff7d"))
	return true

func _update_coins_label() -> void:
	_last_coins = get_coins()
	if coins_label:
		coins_label.text = _fmt(_last_coins)

func _flash_coins(color: Color) -> void:
	coins_label.modulate = color
	var tw := coins_label.create_tween()
	tw.tween_property(coins_label, "modulate", Color.WHITE, 0.4)


# =====================================================================
#  RECURSOS (texturas, estilos, fontes, helpers)
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
	elif FileAccess.file_exists(path):  # existe mas a Godot ainda não importou
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			t = ImageTexture.create_from_image(img)
	if t == null:
		push_warning("NpcMenu: imagem não encontrada: " + path)
	_tex_cache[rel] = t
	return t

func _load_font(file: String) -> Font:
	var path := assets_folder + "fonts/" + file
	return load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font

## StyleBox 9-patch a partir de ui/<name>.png. content = margens internas (l, t, r, b).
func _nine(name: String, content := Vector4(0, 0, 0, 0)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex("ui/%s.png" % name)
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

func _tinted(sb: StyleBoxTexture, c: Color) -> StyleBoxTexture:
	var d := sb.duplicate() as StyleBoxTexture
	d.modulate_color = c
	return d

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

## Texto centralizado que quebra linha, com espaçamento de linha reduzido.
func _wrap_label(text: String, size: int, color := C_SOFT) -> Label:
	var l := _label(text, size, color, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("line_spacing", -3)
	l.custom_minimum_size.x = 100
	return l

## Maior tamanho de fonte (entre min_size e max_size) em que o texto cabe na largura.
func _fit_size(text: String, width: float, max_size: int, min_size: int, font: Font = null) -> int:
	var f := font if font else _font_bold
	for size in range(max_size, min_size - 1, -1):
		if f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			return size
	return min_size

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

func _spacer(width := 0, expand := false) -> Control:
	var s := Control.new()
	s.custom_minimum_size.x = width
	if expand:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

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

	var column := VBoxContainer.new()   # janela + mensagem logo abaixo dela
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	window = PanelContainer.new()
	window.custom_minimum_size = panel_size
	window.add_theme_stylebox_override("panel", _nine("window_bg"))
	column.add_child(window)

	message_label = _label("", 12, C_TEXT, false, 2)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.custom_minimum_size.y = 22
	column.add_child(message_label)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	window.add_child(root)
	root.add_child(_build_header())
	root.add_child(_build_tabs())
	root.add_child(_build_body())
	root.add_child(_build_footer())


func _build_header() -> Control:
	var h := Control.new()
	h.custom_minimum_size = Vector2(panel_size.x, 91)

	var title := _img("icons/title_npcs.png", Vector2(338, 48))
	title.position = Vector2(141, 27)
	h.add_child(title)

	var close_btn := TextureButton.new()
	close_btn.texture_normal = _tex("icons/close_btn.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.offset_left = -73
	close_btn.offset_right = -19
	close_btn.offset_top = 25
	close_btn.offset_bottom = 76
	close_btn.pressed.connect(close_menu)
	_juicy(close_btn)
	h.add_child(close_btn)
	return h


func _build_tabs() -> Control:
	var m := _margin(16, 0, 14, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	m.add_child(h)
	for i in TABS.size():
		var b := _make_tab(i)
		h.add_child(b)
		if i == 0:
			b.button_pressed = true
	return m


func _make_tab(i: int) -> Button:
	var t: Dictionary = TABS[i]
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = tab_group
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(t["width"], 48)
	b.add_theme_stylebox_override("normal", _nine("tab_normal"))
	b.add_theme_stylebox_override("hover", _nine("tab_hover"))
	b.add_theme_stylebox_override("pressed", _nine("tab_active"))
	b.add_theme_stylebox_override("hover_pressed", _nine("tab_active"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var m := _margin(8, 0, 6, 0)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 5)
	h.add_child(_img(t["icon"], Vector2(30, 30)))
	h.add_child(_label(t["title"], 11, C_TEXT, true, 3))
	m.add_child(h)
	b.add_child(m)
	_ignore_mouse(m)

	b.pressed.connect(_select_tab.bind(i))
	_juicy(b)
	return b


func _build_body() -> Control:
	var m := _margin(14, 6, 14, 0)
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.add_child(scroll)

	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	scroll.add_child(grid)
	return m


## Rodapé: saldo dentro da moldura (o desenho da moldura já está na imagem da janela)
func _build_footer() -> Control:
	var c := CenterContainer.new()
	c.custom_minimum_size.y = 50
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(_img("icons/coin.png", Vector2(26, 26)))
	coins_label = _label("", 22, C_GOLD, true, 3)
	h.add_child(coins_label)
	c.add_child(h)
	return c


# =====================================================================
#  ABAS E CARTÕES
# =====================================================================
func _select_tab(index: int) -> void:
	current_tab = index
	_populate_cards(true)


func _populate_cards(animate := false) -> void:
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()

	var tab: Dictionary = TABS[current_tab]
	if tab["view"] == "soon":
		grid.columns = 1
		var soon := _img("icons/coming_soon.png", Vector2(panel_size.x - 28.0, panel_size.y - 195.0))
		soon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		soon.clip_contents = true
		grid.add_child(soon)
		return

	grid.columns = 3
	for npc in NPCS.get(tab["id"], []):
		grid.add_child(_make_miner_card(npc) if tab["view"] == "miner" else _make_scenery_card(npc))

	if animate:
		var i := 0
		for card in grid.get_children():
			card.modulate.a = 0.0
			var tw: Tween = card.create_tween()
			tw.tween_interval(i * 0.05)
			tw.tween_property(card, "modulate:a", 1.0, 0.18)
			i += 1


# ---------------------------- Cartão: MINERADOR ----------------------------
func _make_miner_card(npc: Dictionary) -> Control:
	var id: String = npc["id"]
	var owned := get_npc_count(id)
	var maxed := owned >= int(npc["limit"])

	var card := PanelContainer.new()
	card.custom_minimum_size.x = CARD_W
	card.add_theme_stylebox_override("panel", _nine("card_miner", Vector4(9, 5, 9, 8)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)

	# Título
	var title := _label(npc["name"], _fit_size(npc["name"], 156.0, 14, 9), C_TEXT, true, 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	# Retrato (esquerda) + Desempenho / Experiência (direita)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 3)
	v.add_child(mid)
	var portrait := _img("portraits/%s.png" % npc["portrait"], Vector2(70, 86))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(portrait)
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("separation", 3)
	mid.add_child(stats)
	stats.add_child(_stat_box("icons/stat_pick.png", "Desempenho", int(npc.get("perf", -1)), C_PERF))
	stats.add_child(_stat_box("icons/stat_star.png", "Experiência", int(npc.get("exp", -1)), C_EXP))

	# Descrição
	var desc_box := PanelContainer.new()
	desc_box.add_theme_stylebox_override("panel", _nine("desc_box", Vector4(8, 3, 8, 4)))
	desc_box.custom_minimum_size.y = 30
	desc_box.add_child(_wrap_label(npc["desc"], 9))
	v.add_child(desc_box)

	# Faixa de bônus (opcional)
	if npc.has("bonus"):
		v.add_child(_bonus_banner(npc["bonus"]))

	# Preço / possui / limite
	v.add_child(_miner_price_box(npc["price"], owned, int(npc["limit"])))

	var btn := _make_buy_button(maxed)
	btn.pressed.connect(_on_buy_pressed.bind(id))
	v.add_child(btn)
	return card


func _stat_box(icon_rel: String, label: String, value: int, color: Color) -> Control:
	var box := PanelContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", _nine("stat_box", Vector4(6, 2, 5, 2)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	box.add_child(h)
	h.add_child(_img(icon_rel, Vector2(18, 18)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(_label(label, 8, C_SOFT, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.add_child(_bar(value, color))
	row.add_child(_label("?/10" if value < 0 else "%d/10" % value, 8, C_TEXT, true))
	v.add_child(row)
	return box


## Barra de 10 segmentos (valor -1 = desconhecido: só 1 segmento apagado)
func _bar(value: int, color: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 1)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var filled := 1 if value < 0 else value
	for i in 10:
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(3, 6)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < filled:
			seg.color = color.darkened(0.5) if value < 0 else color
		else:
			seg.color = C_BAR_OFF
		h.add_child(seg)
	return h


func _bonus_banner(text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _nine("bonus_banner", Vector4(8, 2, 8, 2)))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 4)
	p.add_child(h)
	h.add_child(_img("icons/crown.png", Vector2(20, 16)))
	var l := _wrap_label(text, 8, C_GOLD)
	l.add_theme_font_override("font", _font_bold)
	l.custom_minimum_size.x = 90
	h.add_child(l)
	return p


func _miner_price_box(price: int, owned: int, limit: int) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _nine("price_box", Vector4(8, 2, 8, 3)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	box.add_child(v)

	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 4)
	r1.add_child(_img("icons/coin.png", Vector2(22, 22)))
	r1.add_child(_label(_fmt(price), 14, C_TEXT, true, 2))
	r1.add_child(_spacer(0, true))
	r1.add_child(_img("icons/person.png", Vector2(15, 15)))
	r1.add_child(_label("Possui: %d" % owned, 9, C_SOFT, false))
	v.add_child(r1)

	var r2 := HBoxContainer.new()
	r2.alignment = BoxContainer.ALIGNMENT_CENTER
	r2.add_theme_constant_override("separation", 4)
	r2.add_child(_img("icons/lock.png", Vector2(12, 12)))
	r2.add_child(_label("Limite: %d" % limit, 9, C_SOFT, false))
	v.add_child(r2)
	return box


# ---------------------------- Cartão: CENÁRIO ----------------------------
func _make_scenery_card(npc: Dictionary) -> Control:
	var id: String = npc["id"]
	var owned := get_npc_count(id)
	var limit: int = npc["limit"]
	var maxed := owned >= limit

	var card := PanelContainer.new()
	card.custom_minimum_size.x = CARD_W
	card.add_theme_stylebox_override("panel", _nine("card_scenery", Vector4(10, 3, 10, 8)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)

	# Título (dentro da faixa do topo)
	var title := _label(npc["name"], _fit_size(npc["name"], 150.0, 15, 10), C_TEXT, true, 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 28
	v.add_child(title)

	# Retrato grande (com o fundo quadriculado)
	var portrait := _img("portraits/%s.png" % npc["portrait"], Vector2(162, 92))
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.clip_contents = true
	v.add_child(portrait)

	# Descrição
	var desc_box := PanelContainer.new()
	desc_box.add_theme_stylebox_override("panel", _nine("desc_scenery", Vector4(8, 4, 8, 5)))
	desc_box.custom_minimum_size.y = 46
	desc_box.add_child(_wrap_label(npc["desc"], 9, C_TEXT))
	v.add_child(desc_box)

	# Preço e limite
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(_spacer(2))
	row.add_child(_img("icons/coin.png", Vector2(24, 24)))
	row.add_child(_label(_fmt(npc["price"]), 15, C_TEXT, true, 2))
	row.add_child(_spacer(0, true))
	row.add_child(_img("icons/person.png", Vector2(16, 16)))
	var limit_text := "Limite: %d" % limit if owned == 0 else "Limite: %d/%d" % [owned, limit]
	row.add_child(_label(limit_text, 9, C_SOFT, false))
	row.add_child(_spacer(2))
	v.add_child(row)

	var btn := _make_buy_button(maxed)
	btn.pressed.connect(_on_buy_pressed.bind(id))
	v.add_child(btn)
	return card


## Botão verde "COMPRAR" (ou cinza "LIMITE" quando atingiu o máximo)
func _make_buy_button(maxed: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(138, 32)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	var normal := _nine("btn_grey" if maxed else "btn_buy")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", _tinted(normal, Color(1.12, 1.12, 1.12)))
	b.add_theme_stylebox_override("pressed", _tinted(normal, Color(0.82, 0.82, 0.82)))
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = maxed

	var m := _margin(6, 0, 6, 2)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 5)
	if not maxed:
		h.add_child(_img("icons/coin.png", Vector2(22, 22)))
	h.add_child(_label("LIMITE" if maxed else "COMPRAR", 13, C_TEXT, true, 2))
	m.add_child(h)
	b.add_child(m)
	_ignore_mouse(m)
	_juicy(b)
	return b


# =====================================================================
#  COMPRA
# =====================================================================

func _on_buy_pressed(npc_id: String) -> void:
	var npc := _find_npc(npc_id)

	if npc.is_empty():
		return

	# Verifica se existe uma cena disponível para esse NPC.
	var spawner = get_node_or_null("../../Npcs")

	if spawner == null or not spawner.has_method("can_spawn_npc"):
		_toast("Sistema de NPCs não encontrado!", Color("ff6b6b"))
		return

	if not spawner.can_spawn_npc(npc_id):
		_toast("Esse NPC ainda não está disponível!", Color("ffb347"))
		return

	# Verifica o limite de contratação.
	if get_npc_count(npc_id) >= int(npc["limit"]):
		_toast("Limite atingido!", Color("ffb347"))
		return

	# Realiza o pagamento.
	if not _try_spend(npc["price"]):
		return

	
	npc_counts[npc_id] = get_npc_count(npc_id) + 1
	
	if npc_id == "supervisor_mina":
		ativar_bonus_supervisor()
	
	
	npc_purchased.emit(npc_id, npc_counts[npc_id])

	_toast("Contratado: " + npc["name"], Color("7dff7d"))
	_populate_cards()



func _find_npc(npc_id: String) -> Dictionary:
	for list in NPCS.values():
		for npc in list:
			if npc["id"] == npc_id:
				return npc
	return {}


func _toast(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	if toast_tween and toast_tween.is_valid():
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(2.0)
	toast_tween.tween_callback(func(): message_label.text = "")

func ativar_bonus_supervisor():
	if _money != null and _money.has_method("ativar_bonus_supervisor"):
		_money.call("ativar_bonus_supervisor")
