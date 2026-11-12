class_name RoletaLoja
extends Control
## Loja de Roleta
## Monta TODA a interface por código usando as imagens de res://assets/roleta/
## e controla o giro, o sorteio (por porcentagem) e o prêmio.
##
## USO: instancie scenes/roleta_loja.tscn (ou adicione um Control com este script).
## INTEGRAÇÃO com o seu jogo: veja a seção "INTEGRAÇÃO" mais abaixo.

# ----------------------------------------------------------------------------
# SINAIS
# ----------------------------------------------------------------------------
signal giro_iniciado(custo: int)
signal premio_obtido(premio_id: String, tipo: int, valor: int)
signal moedas_insuficientes()
signal fechada()

enum Tipo { MOEDAS, NUKE, SECRETO }

# ----------------------------------------------------------------------------
# CONFIGURAÇÃO (editável no Inspetor)
# ----------------------------------------------------------------------------
@export var pasta_assets: String = "res://assets/roleta/"
@export var custo_giro: int = 100
@export var duracao_giro: float = 5.0
@export_range(4, 10) var voltas_min: int = 5
@export_range(4, 12) var voltas_max: int = 7
@export var fechar_removendo: bool = true          ## true = queue_free() ao fechar; false = só esconde
@export var fonte_personalizada: Font               ## (opcional) fonte bold para combinar com o jogo

@export_group("Sons (opcionais)")
@export var som_giro: AudioStream
@export var som_tick: AudioStream
@export var som_premio: AudioStream
@export var som_erro: AudioStream

@export_group("Modo de teste")
@export var moedas_teste: int = 1000                ## saldo usado quando você NÃO conectou o seu sistema de moedas

# ----------------------------------------------------------------------------
# DADOS DA ROLETA (iguais à imagem de referência)
# Os ângulos são em graus, no sentido horário a partir do topo (onde fica o ponteiro),
# medidos na imagem original da roleta.
# ----------------------------------------------------------------------------
var premios: Array[Dictionary] = [
	{"id": "moedas_50000", "nome": "50.000 moedas", "tipo": Tipo.MOEDAS, "valor": 50000, "chance": 40.0,
	 "ang_min": -44.8, "ang_max": 45.2, "icone": "icone_moedas_50000.png"},
	{"id": "nuke", "nome": "NUKE", "tipo": Tipo.NUKE, "valor": 1, "chance": 5.0,
	 "ang_min": 45.2, "ang_max": 109.6, "icone": "icone_nuke.png"},
	{"id": "moeda_1", "nome": "1 moeda", "tipo": Tipo.MOEDAS, "valor": 1, "chance": 25.0,
	 "ang_min": 109.6, "ang_max": 180.1, "icone": "icone_moeda_1.png"},
	{"id": "moedas_200", "nome": "200 moedas", "tipo": Tipo.MOEDAS, "valor": 200, "chance": 25.0,
	 "ang_min": 180.1, "ang_max": 252.1, "icone": "icone_moedas_200.png"},
	{"id": "secreto", "nome": "Prêmio SECRETO", "tipo": Tipo.SECRETO, "valor": 1, "chance": 5.0,
	 "ang_min": 252.1, "ang_max": 315.2, "icone": "icone_secreto.png"},
]
const DIVISORIAS := [45.2, 109.6, 180.1, 252.1, 315.2]

# ----------------------------------------------------------------------------
# LAYOUT (coordenadas da imagem original 1316x1195)
# ----------------------------------------------------------------------------
const TAMANHO_DESIGN := Vector2(1316, 1195)
const POS_BASE := Vector2(0, 760)
const POS_FACE := Vector2(279, 124)
const PIVO_FACE := Vector2(375.4, 374.8)
const POS_ARO := Vector2(224, 72)
const POS_HUB := Vector2(582, 424)
const POS_PONTEIRO := Vector2(585, 0)
const PIVO_PONTEIRO := Vector2(71.7, 57)
const POS_BOTAO := Vector2(405, 945)

# ----------------------------------------------------------------------------
# ESTADO
# ----------------------------------------------------------------------------
var girando: bool = false
var _rng := RandomNumberGenerator.new()
var _palco: Control
var _face: TextureRect
var _aro: TextureRect
var _hub: TextureRect
var _ponteiro: TextureRect
var _botao: TextureButton
var _lbl_custo: Label
var _lbl_saldo: Label
var _hud_saldo: Control
var _overlay: ColorRect
var _popup: Control
var _popup_icone: TextureRect
var _popup_titulo: Label
var _popup_texto: Label
var _toast: Label
var _tween_giro: Tween
var _tween_ponteiro: Tween
var _tween_aro: Tween
var _ang_anterior: float = 0.0
var _p_giro: AudioStreamPlayer
var _p_tick: AudioStreamPlayer
var _p_premio: AudioStreamPlayer
var _p_erro: AudioStreamPlayer

# ============================================================================
# INTEGRAÇÃO COM O SEU JOGO  <<< EDITE AQUI >>>
# ============================================================================
# Opção 1: atribua Callables antes de adicionar a cena na árvore, ex.:
#   var r = preload("res://scenes/roleta_loja.tscn").instantiate()
#   r.fn_obter_moedas = func(): return Jogador.moedas
#   r.fn_debitar      = func(v): Jogador.moedas -= v
#   r.fn_creditar     = func(v): Jogador.moedas += v
#   r.premio_obtido.connect(_on_premio_roleta)
#   add_child(r)
# Opção 2: edite diretamente as funções _moedas(), _debitar() e _creditar().
var fn_obter_moedas: Callable
var fn_debitar: Callable
var fn_creditar: Callable

func _moedas() -> int:
	if fn_obter_moedas.is_valid():
		return int(fn_obter_moedas.call())
	return moedas_teste

func _debitar(valor: int) -> void:
	if fn_debitar.is_valid():
		fn_debitar.call(valor)
	else:
		moedas_teste -= valor

func _creditar(valor: int) -> void:
	if fn_creditar.is_valid():
		fn_creditar.call(valor)
	else:
		moedas_teste += valor

## Chamada quando o giro termina. Moedas já são creditadas aqui.
## NUKE e SECRETO: o efeito deve ser tratado por você ouvindo o sinal `premio_obtido`
## (ou colocando o seu código no `match` abaixo).
func _aplicar_premio(p: Dictionary) -> void:
	match p["tipo"]:
		Tipo.MOEDAS:
			_creditar(p["valor"])
		Tipo.NUKE:
			pass # ex.: Inventario.adicionar_item("nuke", 1)
		Tipo.SECRETO:
			pass # ex.: Recompensas.liberar_secreto()
	premio_obtido.emit(p["id"], p["tipo"], p["valor"])

# ============================================================================
# CICLO DE VIDA
# ============================================================================
func _ready() -> void:
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_montar_fundo()
	_montar_palco()
	_montar_hud()
	_montar_popup()
	_montar_audio()
	resized.connect(_ajustar_escala)
	_ajustar_escala()
	_atualizar_hud()
	_atualizar_botao()
	_animar_luzes(1.6)
	set_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if _popup.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
			_fechar_popup()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not girando:
		fechar()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_on_girar()
		get_viewport().set_input_as_handled()

func fechar() -> void:
	if girando:
		return
	fechada.emit()
	if fechar_removendo:
		queue_free()
	else:
		hide()

# ============================================================================
# CONSTRUÇÃO DA INTERFACE
# ============================================================================
func _carregar(nome: String) -> Texture2D:
	var caminho := pasta_assets.path_join(nome)
	var t := load(caminho) as Texture2D
	if t == null:
		push_error("RoletaLoja: imagem não encontrada: " + caminho)
	return t

func _tex_rect(nome: String, pos: Vector2, pai: Node = null) -> TextureRect:
	var tr := TextureRect.new()
	var t := _carregar(nome)
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	if t:
		tr.size = t.get_size()
	tr.position = pos
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	(pai if pai else _palco).add_child(tr)
	return tr

func _config_label(tam: int, cor: Color = Color.WHITE, contorno: int = 10,
		cor_contorno: Color = Color(0.05, 0.09, 0.2)) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = tam
	ls.font_color = cor
	ls.outline_size = contorno
	ls.outline_color = cor_contorno
	if fonte_personalizada:
		ls.font = fonte_personalizada
	return ls

func _estilo(fundo: Color, borda: Color, raio: int = 24, largura: int = 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fundo
	s.border_color = borda
	s.set_border_width_all(largura)
	s.set_corner_radius_all(raio)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 8
	return s

func _montar_fundo() -> void:
	var f := ColorRect.new()
	f.color = Color(0.03, 0.06, 0.16, 0.92)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)

func _montar_palco() -> void:
	_palco = Control.new()
	_palco.custom_minimum_size = TAMANHO_DESIGN
	_palco.size = TAMANHO_DESIGN
	_palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_palco)

	# ordem de desenho (de baixo para cima)
	_tex_rect("base.png", POS_BASE)
	_face = _tex_rect("roleta_girante.png", POS_FACE)
	_face.pivot_offset = PIVO_FACE
	_aro = _tex_rect("aro.png", POS_ARO)
	_hub = _tex_rect("hub.png", POS_HUB)
	_hub.pivot_offset = _hub.size / 2.0
	_ponteiro = _tex_rect("ponteiro.png", POS_PONTEIRO)
	_ponteiro.pivot_offset = PIVO_PONTEIRO
	_montar_botao()

func _montar_botao() -> void:
	_botao = TextureButton.new()
	_botao.texture_normal = _carregar("botao_girar.png")
	_botao.size = _botao.texture_normal.get_size()
	_botao.position = POS_BOTAO
	_botao.pivot_offset = _botao.size / 2.0
	_botao.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_botao.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_botao.pressed.connect(_on_girar)
	_botao.button_down.connect(_botao_apertado)
	_botao.button_up.connect(_botao_solto)
	_botao.mouse_entered.connect(_botao_hover)
	_botao.mouse_exited.connect(_atualizar_botao)
	_palco.add_child(_botao)

	var lbl := Label.new()
	lbl.text = "GIRAR"
	lbl.label_settings = _config_label(74, Color.WHITE, 16)
	lbl.position = Vector2(0, 8)
	lbl.size = Vector2(_botao.size.x, 96)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_botao.add_child(lbl)

	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 14)
	linha.position = Vector2(60, 92)
	linha.size = Vector2(_botao.size.x - 120, 70)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_botao.add_child(linha)

	var moeda := TextureRect.new()
	moeda.texture = _carregar("icone_moeda_botao.png")
	moeda.custom_minimum_size = Vector2(58, 55)
	moeda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moeda.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moeda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(moeda)

	_lbl_custo = Label.new()
	_lbl_custo.text = _fmt(custo_giro)
	_lbl_custo.label_settings = _config_label(58, Color.WHITE, 12)
	_lbl_custo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_custo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(_lbl_custo)

func _botao_apertado() -> void:
	if not girando:
		_botao.scale = Vector2(0.96, 0.96)

func _botao_solto() -> void:
	_botao.scale = Vector2.ONE

func _botao_hover() -> void:
	if not girando:
		_botao.modulate = Color(1.12, 1.12, 1.12)

func _montar_hud() -> void:
	# saldo (canto superior esquerdo)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _estilo(Color(0.07, 0.17, 0.42), Color(0.35, 0.65, 1.0), 20, 4))
	pc.position = Vector2(24, 24)
	add_child(pc)
	_hud_saldo = pc
	var mg := MarginContainer.new()
	for lado in ["left", "right"]:
		mg.add_theme_constant_override("margin_" + lado, 18)
	for lado in ["top", "bottom"]:
		mg.add_theme_constant_override("margin_" + lado, 8)
	pc.add_child(mg)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	mg.add_child(h)
	var ic := TextureRect.new()
	ic.texture = _carregar("icone_moeda_botao.png")
	ic.custom_minimum_size = Vector2(44, 42)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(ic)
	_lbl_saldo = Label.new()
	_lbl_saldo.label_settings = _config_label(34, Color.WHITE, 8)
	_lbl_saldo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_lbl_saldo)

	# botão fechar (canto superior direito)
	var x := Button.new()
	x.text = "X"
	x.custom_minimum_size = Vector2(64, 64)
	x.add_theme_font_size_override("font_size", 32)
	x.add_theme_stylebox_override("normal", _estilo(Color(0.85, 0.15, 0.15), Color(1, 0.6, 0.6), 32, 4))
	x.add_theme_stylebox_override("hover", _estilo(Color(1.0, 0.25, 0.25), Color(1, 0.75, 0.75), 32, 4))
	x.add_theme_stylebox_override("pressed", _estilo(Color(0.6, 0.1, 0.1), Color(1, 0.6, 0.6), 32, 4))
	x.add_theme_stylebox_override("disabled", _estilo(Color(0.4, 0.2, 0.2), Color(0.6, 0.4, 0.4), 32, 4))
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(fechar)
	x.name = "BotaoFechar"
	add_child(x)
	x.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)

	# aviso rápido (toast)
	_toast = Label.new()
	_toast.label_settings = _config_label(36, Color(1, 0.9, 0.4), 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 110
	_toast.offset_bottom = 170

func _montar_popup() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(centro)

	var painel := PanelContainer.new()
	painel.add_theme_stylebox_override("panel", _estilo(Color(0.08, 0.2, 0.5), Color(0.98, 0.78, 0.15), 32, 8))
	painel.custom_minimum_size = Vector2(520, 0)
	centro.add_child(painel)
	_popup = painel

	var mg := MarginContainer.new()
	for lado in ["left", "right"]:
		mg.add_theme_constant_override("margin_" + lado, 40)
	for lado in ["top", "bottom"]:
		mg.add_theme_constant_override("margin_" + lado, 32)
	painel.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	mg.add_child(v)

	_popup_titulo = Label.new()
	_popup_titulo.text = "PARABÉNS!"
	_popup_titulo.label_settings = _config_label(54, Color(1, 0.85, 0.2), 14)
	_popup_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_popup_titulo)

	_popup_icone = TextureRect.new()
	_popup_icone.custom_minimum_size = Vector2(240, 180)
	_popup_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_popup_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_popup_icone.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	v.add_child(_popup_icone)

	_popup_texto = Label.new()
	_popup_texto.label_settings = _config_label(40, Color.WHITE, 10)
	_popup_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_popup_texto)

	var ok := Button.new()
	ok.text = "COLETAR"
	ok.custom_minimum_size = Vector2(260, 76)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.add_theme_font_size_override("font_size", 36)
	ok.add_theme_color_override("font_color", Color.WHITE)
	ok.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.05))
	ok.add_theme_constant_override("outline_size", 10)
	ok.add_theme_stylebox_override("normal", _estilo(Color(0.15, 0.7, 0.2), Color(0.6, 1.0, 0.5), 20, 5))
	ok.add_theme_stylebox_override("hover", _estilo(Color(0.2, 0.85, 0.25), Color(0.75, 1.0, 0.6), 20, 5))
	ok.add_theme_stylebox_override("pressed", _estilo(Color(0.1, 0.5, 0.15), Color(0.6, 1.0, 0.5), 20, 5))
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_fechar_popup)
	v.add_child(ok)

func _montar_audio() -> void:
	_p_giro = _criar_player(som_giro)
	_p_tick = _criar_player(som_tick)
	_p_premio = _criar_player(som_premio)
	_p_erro = _criar_player(som_erro)

func _criar_player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p

func _tocar(p: AudioStreamPlayer) -> void:
	if p and p.stream:
		p.play()

# ============================================================================
# ESCALA / HUD
# ============================================================================
func _ajustar_escala() -> void:
	if _palco == null:
		return
	var e: float = minf(size.x / TAMANHO_DESIGN.x, size.y / TAMANHO_DESIGN.y) * 0.95
	_palco.scale = Vector2(e, e)
	_palco.position = (size - TAMANHO_DESIGN * e) / 2.0

func _atualizar_hud() -> void:
	_lbl_saldo.text = _fmt(_moedas())
	_lbl_custo.text = _fmt(custo_giro)

func _atualizar_botao() -> void:
	if _botao == null:
		return
	_botao.disabled = girando
	_botao.scale = Vector2.ONE
	_botao.modulate = Color(0.55, 0.55, 0.55) if girando else Color.WHITE
	var x := get_node_or_null("BotaoFechar") as Button
	if x:
		x.disabled = girando

func _fmt(n: int) -> String:
	var s := str(absi(n))
	var saida := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		saida = s[i] + saida
		c += 1
		if c % 3 == 0 and i > 0:
			saida = "." + saida
	return ("-" if n < 0 else "") + saida

func _avisar(texto: String) -> void:
	_toast.text = texto
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.12)
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)

func _balancar(no: Control) -> void:
	var x0 := no.position.x
	var tw := create_tween()
	for d in [14.0, -14.0, 9.0, -9.0, 0.0]:
		tw.tween_property(no, "position:x", x0 + d, 0.05)

# ============================================================================
# LÓGICA DA ROLETA
# ============================================================================
func _sortear() -> Dictionary:
	var total := 0.0
	for p in premios:
		total += float(p["chance"])
	var r := _rng.randf() * total
	var acc := 0.0
	for p in premios:
		acc += float(p["chance"])
		if r < acc:
			return p
	return premios[premios.size() - 1]

func _on_girar() -> void:
	if girando or _popup.visible:
		return
	if _moedas() < custo_giro:
		moedas_insuficientes.emit()
		_avisar("Moedas insuficientes!")
		_balancar(_hud_saldo)
		_tocar(_p_erro)
		return
	_debitar(custo_giro)
	_atualizar_hud()
	giro_iniciado.emit(custo_giro)

	var premio := _sortear()
	# ponto aleatório dentro da fatia sorteada (com margem para não parar na divisória)
	var margem := 5.0
	var alvo_ang := _rng.randf_range(float(premio["ang_min"]) + margem, float(premio["ang_max"]) - margem)

	# a roda gira no sentido horário; o ponteiro fica no topo (0°)
	var rot_atual: float = _face.rotation_degrees
	var alvo_mod := fposmod(-alvo_ang, 360.0)
	var atual_mod := fposmod(rot_atual, 360.0)
	var delta := fposmod(alvo_mod - atual_mod, 360.0)
	var voltas := _rng.randi_range(voltas_min, maxi(voltas_min, voltas_max))
	var rot_final := rot_atual + voltas * 360.0 + delta

	girando = true
	_atualizar_botao()
	_ang_anterior = fposmod(-rot_atual, 360.0)
	set_process(true)
	_animar_luzes(0.25)
	_tocar(_p_giro)

	if _tween_giro and _tween_giro.is_valid():
		_tween_giro.kill()
	_tween_giro = create_tween()
	_tween_giro.tween_property(_face, "rotation_degrees", rot_final, duracao_giro) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween_giro.tween_callback(_finalizar_giro.bind(premio))

	# pequeno "pulo" do hub ao iniciar
	var th := create_tween()
	th.tween_property(_hub, "scale", Vector2(1.12, 1.12), 0.1)
	th.tween_property(_hub, "scale", Vector2.ONE, 0.2)

func _process(_dt: float) -> void:
	if not girando:
		return
	# estalo do ponteiro cada vez que uma divisória passa por ele
	var ang := fposmod(-_face.rotation_degrees, 360.0)
	for d in DIVISORIAS:
		if _cruzou(_ang_anterior, ang, float(d)):
			_flick_ponteiro()
			break
	_ang_anterior = ang

func _cruzou(a: float, b: float, limite: float) -> bool:
	var passo := wrapf(b - a, -180.0, 180.0)
	var ate := wrapf(limite - a, -180.0, 180.0)
	return absf(passo) > 0.0001 and signf(ate) == signf(passo) and absf(ate) <= absf(passo)

func _flick_ponteiro() -> void:
	if _tween_ponteiro and _tween_ponteiro.is_valid():
		_tween_ponteiro.kill()
	_tween_ponteiro = create_tween()
	_tween_ponteiro.tween_property(_ponteiro, "rotation_degrees", -24.0, 0.04)
	_tween_ponteiro.tween_property(_ponteiro, "rotation_degrees", 0.0, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tocar(_p_tick)

func _finalizar_giro(premio: Dictionary) -> void:
	girando = false
	set_process(false)
	_ponteiro.rotation_degrees = 0.0
	_animar_luzes(1.6)
	_aplicar_premio(premio)
	_atualizar_hud()
	_atualizar_botao()
	_mostrar_popup(premio)

# ============================================================================
# POPUP DO PRÊMIO
# ============================================================================
func _mostrar_popup(p: Dictionary) -> void:
	_popup_icone.texture = _carregar(p["icone"])
	match p["tipo"]:
		Tipo.MOEDAS:
			_popup_titulo.text = "PARABÉNS!"
			if int(p["valor"]) == 1:
				_popup_texto.text = "Você ganhou\n1 moeda!"
			else:
				_popup_texto.text = "Você ganhou\n%s moedas!" % _fmt(int(p["valor"]))
		Tipo.NUKE:
			_popup_titulo.text = "BOOM!"
			_popup_texto.text = "Você ganhou uma NUKE!"
		Tipo.SECRETO:
			_popup_titulo.text = "INCRÍVEL!"
			_popup_texto.text = "Você desbloqueou o\nprêmio SECRETO!"
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	_popup.pivot_offset = _popup.size / 2.0
	_popup.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.2)
	tw.tween_property(_popup, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tocar(_p_premio)
	# o painel só tem o tamanho final no próximo frame
	await get_tree().process_frame
	if is_instance_valid(_popup):
		_popup.pivot_offset = _popup.size / 2.0

func _fechar_popup() -> void:
	_overlay.visible = false

# ============================================================================
# EFEITO DAS LUZES DO ARO (pulsa mais rápido durante o giro)
# ============================================================================
func _animar_luzes(periodo: float) -> void:
	if _tween_aro and _tween_aro.is_valid():
		_tween_aro.kill()
	_tween_aro = create_tween().set_loops()
	_tween_aro.tween_property(_aro, "self_modulate", Color(1.22, 1.22, 1.22), periodo * 0.5) \
		.set_trans(Tween.TRANS_SINE)
	_tween_aro.tween_property(_aro, "self_modulate", Color.WHITE, periodo * 0.5) \
		.set_trans(Tween.TRANS_SINE)
