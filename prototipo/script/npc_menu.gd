extends Control
class_name NpcMenu
## LOJA DE NPCs - Mineradores (e abas futuras). Godot 4.2+
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
@export var panel_size := Vector2(570, 660)
## Escala visual do menu inteiro (0.7 = 70%).
@export_range(0.3, 2.0, 0.05) var ui_scale := 1.0
@export var play_open_animation := true
## Marque para o menu já começar fechado (abra com open_menu()).
@export var start_hidden := false
@export var assets_folder := "res://assets/npc/"

# ======================= DADOS (edite à vontade) =======================
# width = largura da aba (px). A aba só mostra NPCs se existir lista em NPCS[id].
var TABS := [
	{"id": "miners",  "title": "MINERADORES", "icon": "icons/tab_miners.png",  "width": 153},
	{"id": "scenery", "title": "CENÁRIO",     "icon": "icons/tab_scenery.png", "width": 125},
	{"id": "special", "title": "ESPECIAIS",   "icon": "icons/tab_special.png", "width": 130},
	{"id": "secret",  "title": "SECRETOS",    "icon": "icons/tab_secret.png",  "width": 125},
]

# id (único) | name | desc | price | limit (máx. que o jogador pode ter) | portrait (arquivo em portraits/)
var NPCS := {
	"miners": [
		{"id": "minerador_iniciante",    "name": "Minerador Iniciante",    "desc": "Um trabalhador recém-chegado à mineração.",           "price": 100,   "limit": 10, "portrait": "minerador_iniciante"},
		{"id": "minerador_auxiliar",     "name": "Minerador Auxiliar",     "desc": "Estou trabalhando e mantendo o ritmo da operação.",   "price": 1000,  "limit": 5,  "portrait": "minerador_auxiliar"},
		{"id": "minerador_experiente",   "name": "Minerador Experiente",   "desc": "Trabalhador experiente, eficiente e resistente.",     "price": 3000,  "limit": 5,  "portrait": "minerador_experiente"},
		{"id": "minerador_explorador",   "name": "Minerador Explorador",   "desc": "Explora a mina e procura novas áreas de recursos.",   "price": 5000,  "limit": 3,  "portrait": "minerador_explorador"},
		{"id": "minerador_especialista", "name": "Minerador Especialista", "desc": "Especialista em mineração, altamente eficiente.",     "price": 10000, "limit": 5,  "portrait": "minerador_especialista"},
		{"id": "supervisor_mina",        "name": "Supervisor de Mina",     "desc": "Observa os trabalhadores e acompanha as atividades da mina.", "price": 20000, "limit": 1, "portrait": "supervisor_mina"},
	],
	"scenery": [],
	"special": [],
	"secret": [],
}

# Margens dos 9-patch (l, t, r, b) na escala de tela. Só mude se trocar a imagem.
var MARGINS := {
	"window_bg": [138, 152, 115, 24], "card_frame": [18, 18, 18, 18], "stats_box": [9, 9, 9, 9],
	"btn_buy": [15, 12, 15, 12], "btn_grey": [15, 12, 15, 12],
	"tab_active": [20, 20, 20, 20], "tab_normal": [20, 20, 20, 20], "tab_hover": [20, 20, 20, 20],
}

const CARD_SIZE := Vector2(174, 224)
const C_TEXT := Color.WHITE
const C_DESC := Color("9fd0ff")
const C_SOFT := Color("cfe3ff")

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

	window = PanelContainer.new()
	window.custom_minimum_size = panel_size
	window.add_theme_stylebox_override("panel", _nine("window_bg", Vector4(11, 6, 12, 16)))
	center.add_child(window)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	window.add_child(root)
	root.add_child(_build_header())
	root.add_child(_build_tabs())
	root.add_child(_build_body())


func _build_header() -> Control:
	var m := _margin(0, 12, 0, 0)
	m.custom_minimum_size.y = 90
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 0)
	m.add_child(h)

	h.add_child(_spacer(125))                                   # espaço do carrinho de minério
	h.add_child(_img("icons/title_npcs.png", Vector2(328, 52)))
	h.add_child(_spacer(0, true))

	var close_btn := TextureButton.new()
	close_btn.texture_normal = _tex("icons/close_btn.png")
	close_btn.ignore_texture_size = true
	close_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_btn.custom_minimum_size = Vector2(51, 50)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close_menu)
	_juicy(close_btn)
	h.add_child(close_btn)
	h.add_child(_spacer(4))
	return m


func _build_tabs() -> Control:
	var m := _margin(0, 6, 0, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
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
	b.custom_minimum_size = Vector2(t["width"], 44)
	b.add_theme_stylebox_override("normal", _nine("tab_normal"))
	b.add_theme_stylebox_override("hover", _nine("tab_hover"))
	b.add_theme_stylebox_override("pressed", _nine("tab_active"))
	b.add_theme_stylebox_override("hover_pressed", _nine("tab_active"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var m := _margin(8, 0, 8, 0)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	h.add_child(_img(t["icon"], Vector2(30, 30)))
	h.add_child(_label(t["title"], 11, C_TEXT, true, 3))
	m.add_child(h)
	b.add_child(m)
	_ignore_mouse(m)

	b.pressed.connect(_select_tab.bind(i))
	_juicy(b)
	return b


func _build_body() -> Control:
	var m := _margin(3, 8, 3, 0)
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 11)
	scroll.add_child(grid)

	# Rodapé: saldo (esquerda) e mensagens (direita)
	var f := HBoxContainer.new()
	f.custom_minimum_size.y = 24
	f.add_theme_constant_override("separation", 5)
	f.add_child(_img("icons/coin.png", Vector2(18, 18)))
	coins_label = _label("", 14, Color("ffd23a"), true, 2)
	f.add_child(coins_label)
	f.add_child(_spacer(0, true))
	message_label = _label("", 10, C_TEXT, false)
	f.add_child(message_label)
	v.add_child(f)
	return m


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

	var list: Array = NPCS.get(TABS[current_tab]["id"], [])
	if list.is_empty():
		grid.columns = 1
		grid.add_child(_coming_soon())
		return

	grid.columns = 3
	for npc in list:
		grid.add_child(_make_card(npc))

	if animate:
		var i := 0
		for card in grid.get_children():
			card.modulate.a = 0.0
			var tw: Tween = card.create_tween()
			tw.tween_interval(i * 0.05)
			tw.tween_property(card, "modulate:a", 1.0, 0.18)
			i += 1


func _coming_soon() -> Control:
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2(540, 260)
	c.add_child(_label("Em breve...", 20, C_SOFT))
	return c


func _make_card(npc: Dictionary) -> Control:
	var id: String = npc["id"]
	var owned := get_npc_count(id)
	var limit: int = npc["limit"]
	var maxed := owned >= limit

	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.add_theme_stylebox_override("panel", _nine("card_frame", Vector4(10, 6, 10, 8)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)

	# Retrato
	var portrait := TextureRect.new()
	portrait.texture = _tex("portraits/%s.png" % npc["portrait"])
	portrait.custom_minimum_size = Vector2(154, 70)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.clip_contents = true
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(portrait)

	# Nome e descrição
	var name_l := _label(npc["name"], 13, C_TEXT, true, 2)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var desc := _label(npc["desc"], _fit_desc_size(npc["desc"], 154.0), C_DESC, false)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(150, 26)
	v.add_child(desc)

	v.add_child(_make_stats(npc["price"], owned, limit))
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(fill)

	# Botão comprar
	var btn := _make_buy_button(maxed)
	btn.pressed.connect(_on_buy_pressed.bind(id))
	v.add_child(btn)
	return card


## Maior tamanho de fonte (10 a 8) em que a descrição cabe em até 2 linhas.
func _fit_desc_size(text: String, width: float) -> int:
	for size in [10, 9, 8]:
		var h := _font_med.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y
		if h <= _font_med.get_height(size) * 2.0 + 1.0:
			return size
	return 8


## Caixa com preço, quantidade que possui e limite
func _make_stats(price: int, owned: int, limit: int) -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _nine("stats_box", Vector4(8, 3, 8, 3)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	box.add_child(v)

	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 4)
	r1.add_child(_img("icons/coin.png", Vector2(20, 20)))
	r1.add_child(_label(_fmt(price), 14, C_TEXT, true, 2))
	r1.add_child(_spacer(0, true))
	r1.add_child(_img("icons/person.png", Vector2(14, 14)))
	r1.add_child(_label("Possui: %d" % owned, 9, C_SOFT, false))
	v.add_child(r1)

	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 4)
	r2.add_child(_spacer(4))
	r2.add_child(_img("icons/lock.png", Vector2(12, 12)))
	r2.add_child(_label("Limite: %d" % limit, 9, C_SOFT, false))
	v.add_child(r2)
	return box


## Botão verde "COMPRAR" (ou cinza "LIMITE" quando atingiu o máximo)
func _make_buy_button(maxed: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(130, 32)
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
	if get_npc_count(npc_id) >= int(npc["limit"]):
		_toast("Limite atingido!", Color("ffb347"))
		return
	if not _try_spend(npc["price"]):
		return
	npc_counts[npc_id] = get_npc_count(npc_id) + 1
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

# =====================================================================
#  ESTRUTURA DE PASTAS ESPERADA (res://assets/npc/)
#    ui/        -> window_bg, card_frame, stats_box, btn_buy, btn_grey, tab_*
#    icons/     -> title_npcs, close_btn, coin, person, lock, tab_*
#    portraits/ -> um PNG por NPC (nome = campo "portrait")
#    fonts/     -> Poppins-Bold.ttf, Poppins-Medium.ttf
# =====================================================================
