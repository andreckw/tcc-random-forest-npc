
extends Node2D

## Cena usada para o teste manual pela tecla N.
@export var npc_scene: PackedScene

## Posição onde os NPCs comprados aparecerão.
@export var spawn_position: Vector2 = Vector2(590, 240)

## Relação entre o ID da loja e a cena correspondente.
const NPC_SCENES := {
	# MINERADORES
	"minerador_iniciante": "res://scenes/npc/NPCbeginner.tscn",
	"minerador_auxiliar": "res://scenes/npc/NPCaux.tscn",
	"minerador_experiente": "res://scenes/npc/NPCexperienced.tscn",
	"minerador_explorador": "res://scenes/npc/NPCexplorer.tscn",
	"minerador_especialista": "res://scenes/npc/NPCsenior.tscn",
	"supervisor_mina": "res://scenes/npc/NPCmanager.tscn",

	# NPCs DE CENÁRIO (cenas futuras)
	"campones": "res://scenes/npc/NPCpeasant.tscn",
	"comerciante": "res://scenes/npc/NPCmerchant.tscn",
	"professor": "res://scenes/npc/NPCteacher.tscn",
	"cavaleiro": "res://scenes/npc/NPCknight.tscn",
	"arqueiro": "res://scenes/npc/NPCarcher.tscn",
	"mago": "res://scenes/npc/NPCwizard.tscn"
}


func _ready() -> void:
	var loja = get_node_or_null("../CanvasLayer/NPC")

	if loja == null:
		push_error("Npcs: não foi possível encontrar CanvasLayer/NPC!")
		return

	if not loja.is_connected("npc_purchased", _on_npc_purchased):
		loja.connect("npc_purchased", _on_npc_purchased)


## Verifica se existe uma cena configurada e disponível para o NPC.
func can_spawn_npc(npc_id: String) -> bool:
	if not NPC_SCENES.has(npc_id):
		return false

	var caminho: String = NPC_SCENES[npc_id]
	return ResourceLoader.exists(caminho)


## Recebe a notificação de compra da loja.
func _on_npc_purchased(npc_id: String, total_owned: int) -> void:
	print("NPC comprado: ", npc_id, " | Total: ", total_owned)

	if not can_spawn_npc(npc_id):
		push_warning("Npcs: cena não encontrada para o NPC: " + npc_id)
		return

	var caminho: String = NPC_SCENES[npc_id]
	var cena: PackedScene = load(caminho) as PackedScene

	if cena == null:
		push_error("Npcs: não foi possível carregar: " + caminho)
		return

	instanciar_npc(cena)


## Instancia o NPC na posição configurada.
func instanciar_npc(cena: PackedScene) -> void:
	var npc = cena.instantiate()

	# Desativa a geração de dataset.
	npc.set("GerarDataset", false)

	add_child(npc)
	npc.position = spawn_position

	print("NPC apareceu na posição: ", spawn_position)


## Mantém o teste manual pela tecla N.
func spawnar_npc() -> void:
	if npc_scene == null:
		push_error("Nenhuma cena de NPC foi configurada!")
		return

	instanciar_npc(npc_scene)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_N:
			spawnar_npc()
