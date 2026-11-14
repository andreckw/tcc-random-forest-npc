extends Control
class_name Roleta


signal spin_started
signal spin_finished(prize_id: String)
signal prize_won(prize_id: String, amount: int)   # disparado para TODOS os prêmios
signal tick                                       # a cada fatia que passa pelo ponteiro
signal closed

@onready var spin_sound: AudioStreamPlayer = $SpinSound

## Nome do Autoload de dinheiro (Projeto > Configurações > Autoload). Vazio = detecta sozinho.
@export var money_autoload := ""
@export var spin_cost := 100
@export_range(2.0, 12.0, 0.5) var spin_duration := 5.0
## Escala visual da roleta inteira (0.8 = 80%).
@export_range(0.3, 2.0, 0.05) var ui_scale := 1.0
@export var play_open_animation := true
## Marque para a roleta já começar fechada (abra com open_roleta()).
@export var start_hidden := false
@export var dim_background := true
## Clicar fora da roleta fecha (só quando ela não está girando). O Esc também fecha.
@export var close_on_dim_click := true
@export var assets_folder := "res://assets/roleta/"

# ======================= DADOS (edite à vontade) =======================
# wedge: qual fatia (cor) do desenho. weight: chance relativa (a % mostrada é calculada).
# type: "coins" (paga em dinheiro) ou "item" (você entrega pelo sinal prize_won).
# icon_size: tamanho do ícone na tela.
var PRIZES := [
	{
		"id": "coins_50000",
		"wedge": "yellow",
		"label": "50.000",
		"weight": 40,
		"real_weight": 5,
		"type": "coins",
		"amount": 50000,
		"icon": "prize_coins_big",
		"icon_size": Vector2(104, 60),
		"font": 23
	},
	{
		"id": "nuke",
		"wedge": "purple",
		"label": "NUKE",
		"weight": 5,
		"real_weight": 5,
		"type": "item",
		"amount": 1,
		"icon": "prize_nuke",
		"icon_size": Vector2(78, 65),
		"font": 19
	},
	{
		"id": "coins_1",
		"wedge": "blue",
		"label": "1",
		"weight": 25,
		"real_weight": 45,
		"type": "coins",
		"amount": 1,
		"icon": "prize_coin",
		"icon_size": Vector2(65, 56),
		"font": 23
	},
	{
		"id": "coins_200",
		"wedge": "green",
		"label": "200",
		"weight": 25,
		"real_weight": 45,
		"type": "coins",
		"amount": 200,
		"icon": "prize_coins_med",
		"icon_size": Vector2(77, 54),
		"font": 23
	},
	{
		"id": "secret_npc",
		"wedge": "red",
		"label": "SECRETO",
		"weight": 5,
		"real_weight": 0,
		"type": "item",
		"amount": 1,
		"icon": "prize_secret",
		"icon_size": Vector2(62, 72),
		"font": 19
	},
]

# Geometria do desenho (ângulos em graus, no sentido horário a partir do topo; pos = centro do
# conteúdo da fatia em relação ao centro da roleta). Só mude se trocar a imagem do disco.
var WEDGES := {
	"yellow": {"from": -43.5, "to": 44.5,  "pos": Vector2(0, -105),   "pill": "pill_yellow"},
	"purple": {"from": 44.5,  "to": 109.5, "pos": Vector2(115, -29),  "pill": "pill_purple"},
	"blue":   {"from": 109.5, "to": 180.0, "pos": Vector2(65, 94),    "pill": "pill_blue"},
	"green":  {"from": 180.0, "to": 250.5, "pos": Vector2(-68, 95),   "pill": "pill_green"},
	"red":    {"from": 250.5, "to": 316.5, "pos": Vector2(-106, -33), "pill": "pill_red"},
}
const PILL_MARGIN := [13, 11, 13, 11]
const BTN_MARGIN := [25, 18, 25, 18]

const FRAME_SIZE := Vector2(440, 582)
const WHEEL_CENTER := Vector2(217, 245.85)
const DISK_SIZE := 372.0
const BTN_RECT := Rect2(93, 470, 249, 91)
const BULBS := [
	Vector2(298.0, 64.9), Vector2(359.7, 112.4), Vector2(398.7, 177.5), Vector2(411.0, 244.8),
	Vector2(399.2, 312.8), Vector2(362.6, 374.1), Vector2(304.6, 421.2), Vector2(216.9, 443.1),
	Vector2(127.6, 421.2), Vector2(70.1, 373.9), Vector2(34.2, 312.7), Vector2(22.3, 244.9),
	Vector2(36.3, 176.7), Vector2(76.4, 111.9), Vector2(139.3, 65.2),
]
const C_TEXT := Color.WHITE
const C_OUTLINE := Color("05091e")
const C_GOLD := Color("ffd23a")

# ======================= ESTADO =======================
var _spinning := false
var _last_wedge := ""
var _tween: Tween
var _toast_tween: Tween
var _blink_phase := 0
var _money: Node
var _tex_cache := {}
var _font_bold: Font

# ======================= UI =======================
var stage: Control
var disk: Control
var markers: Array[Control] = []
var marker_by_prize := {}
var bulb_nodes: Array[TextureRect] = []
var spin_button: Button
var message_label: Label
var blink_timer: Timer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_money = _find_money()
	_font_bold = _load_font("Poppins-Bold.ttf")
	_build_ui()
	_play_open()
	if start_hidden:
		hide()


func _process(_delta: float) -> void:
	if not visible:
		return
	# O conteúdo das fatias gira junto com o disco, mas sempre fica em pé
	for m in markers:
		m.rotation = -disk.rotation
	if _spinning:
		var w := _wedge_at(fposmod(-disk.rotation_degrees, 360.0))
		if w != _last_wedge:
			_last_wedge = w
			tick.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not _spinning:
		close_roleta()
		get_viewport().set_input_as_handled()


# =====================================================================
#  API PÚBLICA
# =====================================================================
func open_roleta() -> void:
	show()
	message_label.text = ""
	_play_open()

func close_roleta() -> void:
	if _spinning:
		return
	hide()
	closed.emit()

func is_spinning() -> bool:
	return _spinning

func get_coins() -> int:
	return int(_money.dinheiro) if _money else 0

## Gira a roleta (é o que o botão GIRAR chama). Cobra o custo e sorteia o prêmio.
func spin() -> void:
	if _spinning:
		return
	if get_coins() < spin_cost:
		_toast("Moedas insuficientes!", Color("ff6b6b"))
		_shake_button()
		return
	_money.adicionar_dinheiro(-spin_cost)

	var prize := _pick_prize()
	var w: Dictionary = WEDGES[prize["wedge"]]
	var margin: float = (float(w["to"]) - float(w["from"])) * 0.18          # evita parar em cima da linha
	var target := randf_range(float(w["from"]) + margin, float(w["to"]) - margin)
	var current := fposmod(disk.rotation_degrees, 360.0)
	var delta := fposmod(-target - current, 360.0) + 360.0 * randi_range(5, 7)

	_set_spinning(true)
	spin_started.emit()
	spin_sound.play()
	_toast("", C_TEXT)
	_tween = create_tween()
	_tween.tween_property(disk, "rotation_degrees", disk.rotation_degrees + delta, spin_duration) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_on_spin_end.bind(prize))


# =====================================================================
#  SORTEIO E RESULTADO
# =====================================================================
func _pick_prize() -> Dictionary:
	var total := 0.0

	# Calcula o peso REAL dos prêmios.
	for p in PRIZES:
		total += float(p["real_weight"])

	var r := randf() * total

	# Sorteia utilizando apenas as probabilidades reais.
	for p in PRIZES:
		r -= float(p["real_weight"])

		if r <= 0.0:
			return p

	return PRIZES[PRIZES.size() - 1]

func _wedge_at(angle: float) -> String:
	for key in WEDGES:
		var w: Dictionary = WEDGES[key]
		if fposmod(angle - float(w["from"]), 360.0) < float(w["to"]) - float(w["from"]):
			return key
	return ""

func _on_spin_end(prize: Dictionary) -> void:
	_set_spinning(false)
	spin_sound.stop()
	var amount: int = prize["amount"]
	if prize["type"] == "coins" and _money:
		_money.adicionar_dinheiro(amount)
		_toast("Você ganhou %s moedas!" % _fmt(amount), C_GOLD)
	else:
		_toast("Você ganhou: %s!" % prize["label"], C_GOLD)
	_pulse(marker_by_prize.get(prize["id"]))
	prize_won.emit(prize["id"], amount)
	spin_finished.emit(prize["id"])

func _set_spinning(v: bool) -> void:
	_spinning = v
	spin_button.disabled = v
	blink_timer.wait_time = 0.07 if v else 0.55


# =====================================================================
#  DINHEIRO (usa o Autoload do jogo)
# =====================================================================
func _find_money() -> Node:
	if money_autoload != "":
		var n := get_node_or_null("/root/" + money_autoload)
		if n == null:
			push_error("Roleta: Autoload '%s' não encontrado." % money_autoload)
		return n
	for n in get_tree().root.get_children():
		if "dinheiro" in n and n.has_method("adicionar_dinheiro"):
			return n
	push_error("Roleta: nenhum Autoload com 'dinheiro' e 'adicionar_dinheiro()' foi encontrado.")
	return null


# =====================================================================
#  RECURSOS
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
		push_warning("Roleta: imagem não encontrada: " + path)
	_tex_cache[rel] = t
	return t

func _load_font(file: String) -> Font:
	var path := assets_folder + "fonts/" + file
	return load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font

func _nine(rel: String, m: Array, content := Vector4(0, 0, 0, 0)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(rel)
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	sb.content_margin_left = content.x
	sb.content_margin_top = content.y
	sb.content_margin_right = content.z
	sb.content_margin_bottom = content.w
	return sb

func _label(text: String, size: int, color := C_TEXT, outline := 3) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", C_OUTLINE)
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
	dim.color = Color(0, 0, 0, 0.6 if dim_background else 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	stage = Control.new()
	stage.custom_minimum_size = FRAME_SIZE
	stage.mouse_filter = Control.MOUSE_FILTER_STOP   # clicar na roleta não fecha (só fora dela)
	column.add_child(stage)

	message_label = _label("", 18, C_GOLD, 3)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.custom_minimum_size.y = 28
	column.add_child(message_label)

	_build_disk()
	var frame := _img("frame.png", FRAME_SIZE)       # moldura com "buraco": o disco aparece por trás
	frame.size = FRAME_SIZE
	stage.add_child(frame)
	_build_bulbs()
	_build_spin_button()

	blink_timer = Timer.new()
	blink_timer.wait_time = 0.55
	blink_timer.autostart = true
	blink_timer.timeout.connect(_on_blink)
	add_child(blink_timer)
	_on_blink()


func _build_disk() -> void:
	disk = Control.new()
	disk.size = Vector2(DISK_SIZE, DISK_SIZE)
	disk.position = WHEEL_CENTER - disk.size / 2.0
	disk.pivot_offset = disk.size / 2.0
	disk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(disk)

	var base := _img("disk.png", disk.size)
	base.size = disk.size
	disk.add_child(base)

	var total := 0.0
	for p in PRIZES:
		total += float(p["weight"])
	for p in PRIZES:
		var m := _make_marker(p, int(round(float(p["weight"]) * 100.0 / total)))
		disk.add_child(m)
		m.size = m.get_combined_minimum_size()
		m.pivot_offset = m.size / 2.0
		m.position = disk.size / 2.0 + (WEDGES[p["wedge"]]["pos"] as Vector2) - m.size / 2.0
		markers.append(m)
		marker_by_prize[p["id"]] = m


## Ícone + nome do prêmio + pílula com a porcentagem
func _make_marker(p: Dictionary, percent: int) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _img("icons/%s.png" % p["icon"], p["icon_size"])
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	var name_l := _label(p["label"], int(p["font"]), C_TEXT, 4)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.custom_minimum_size = Vector2(64, 24)
	pill.add_theme_stylebox_override("panel", _nine("ui/%s.png" % WEDGES[p["wedge"]]["pill"], PILL_MARGIN, Vector4(8, 0, 8, 1)))
	var pl := _label("%d%%" % percent, 12, C_TEXT, 2)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(pl)
	v.add_child(pill)
	return v


func _build_bulbs() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for pos in BULBS:
		var g := _img("bulb_glow.png", Vector2(48, 48))
		g.size = Vector2(48, 48)
		g.position = pos - g.size / 2.0
		g.material = mat
		g.modulate.a = 0.0
		stage.add_child(g)
		bulb_nodes.append(g)


func _build_spin_button() -> void:
	spin_button = Button.new()
	spin_button.position = BTN_RECT.position
	spin_button.size = BTN_RECT.size
	spin_button.focus_mode = Control.FOCUS_NONE
	var normal := _nine("ui/btn_spin.png", BTN_MARGIN)
	var hover := normal.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.1, 1.1, 1.1)
	var pressed := normal.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.82, 0.82, 0.82)
	spin_button.add_theme_stylebox_override("normal", normal)
	spin_button.add_theme_stylebox_override("hover", hover)
	spin_button.add_theme_stylebox_override("pressed", pressed)
	spin_button.add_theme_stylebox_override("disabled", _nine("ui/btn_spin_grey.png", BTN_MARGIN))
	spin_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("GIRAR", 32, C_TEXT, 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_img("icons/coin.png", Vector2(28, 26)))
	row.add_child(_label(_fmt(spin_cost), 22, C_TEXT, 4))
	v.add_child(row)
	c.add_child(v)
	spin_button.add_child(c)

	spin_button.resized.connect(func(): spin_button.pivot_offset = spin_button.size / 2.0)
	spin_button.mouse_entered.connect(_tween_scale.bind(spin_button, 1.04))
	spin_button.mouse_exited.connect(_tween_scale.bind(spin_button, 1.0))
	spin_button.button_down.connect(_tween_scale.bind(spin_button, 0.96))
	spin_button.button_up.connect(_tween_scale.bind(spin_button, 1.04))
	spin_button.pressed.connect(spin)
	stage.add_child(spin_button)


# =====================================================================
#  ANIMAÇÕES E EFEITOS
# =====================================================================
func _play_open() -> void:
	await get_tree().process_frame
	if stage == null:
		return
	stage.pivot_offset = stage.size / 2.0
	var target := Vector2.ONE * ui_scale
	if not play_open_animation:
		stage.scale = target
		return
	stage.scale = target * 0.9
	stage.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(stage, "scale", target, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stage, "modulate:a", 1.0, 0.18)

func _tween_scale(n: Control, s: float) -> void:
	if n is BaseButton and (n as BaseButton).disabled:
		s = 1.0
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(s, s), 0.08)

## Lâmpadas piscando alternadas (devagar parada, rápido girando)
func _on_blink() -> void:
	if not visible:
		return
	_blink_phase += 1
	for i in bulb_nodes.size():
		var on := (i + _blink_phase) % 2 == 0
		var tw := bulb_nodes[i].create_tween()
		tw.tween_property(bulb_nodes[i], "modulate:a", 0.9 if on else 0.05, 0.12)

func _pulse(m: Control) -> void:
	if m == null:
		return
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector2(1.3, 1.3), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "scale", Vector2.ONE, 0.25)
	tw.set_loops(3)
	for b in bulb_nodes:
		var t2 := b.create_tween()
		t2.tween_property(b, "modulate:a", 1.0, 0.1)

func _shake_button() -> void:
	var x := spin_button.position.x
	var tw := spin_button.create_tween()
	for dx in [-6.0, 6.0, -4.0, 4.0, 0.0]:
		tw.tween_property(spin_button, "position:x", x + dx, 0.05)

func _toast(text: String, color: Color) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	if text != "":
		_toast_tween = create_tween()
		_toast_tween.tween_interval(3.0)
		_toast_tween.tween_callback(func(): message_label.text = "")

func _on_dim_input(event: InputEvent) -> void:
	if close_on_dim_click and event is InputEventMouseButton and event.pressed and not _spinning:
		close_roleta()

# =====================================================================
#  ESTRUTURA DE PASTAS ESPERADA (res://assets/roleta/)
#    frame.png, disk.png, bulb_glow.png
#    ui/     -> btn_spin, btn_spin_grey, pill_yellow/purple/blue/green/red
#    icons/  -> prize_coins_big, prize_nuke, prize_coin, prize_coins_med, prize_secret, coin
#    fonts/  -> Poppins-Bold.ttf, Poppins-Medium.ttf
# =====================================================================
