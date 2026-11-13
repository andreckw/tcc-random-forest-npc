
using Godot;

public partial class MineracaoController : Node
{
	[Export] public int DanoPorAtaque = 2;
	[Export] public float IntervaloAtaque = 1.0f;
	[Export] public float DistanciaParaMinerar = 25f;

	private NpcAgent npc;
	private Node2D minaAlvo;

	private float tempoAtaque = 0f;
	private bool aguardandoNovaAcao = false;

	public override void _Ready()
	{
		npc = GetParent() as NpcAgent;

		if (npc == null)
		{
			GD.PushError("MineracaoController precisa ser filho de um NpcAgent.");
			return;
		}
	}

	public override void _Process(double delta)
	{
		if (npc == null || !npc.PodeMinerar)
			return;

		// Se já existe uma mina escolhida, acompanha o processo.
		if (minaAlvo != null)
		{
			ProcessarMina((float)delta);
			return;
		}

		// Depois de terminar uma mineração, espera a RF escolher outra ação.
		if (aguardandoNovaAcao)
		{
			if (npc.CurrentState.GetType().Name != "PatrolWalk")
				aguardandoNovaAcao = false;

			return;
		}

		// Só procura uma mina quando a RF escolhe PatrolWalk.
		if (npc.CurrentState.GetType().Name != "PatrolWalk")
			return;

		EscolherMina();
	}

	private void EscolherMina()
	{
		var minas = GetTree().GetNodesInGroup("minas");

		float menorDistancia = float.MaxValue;
		Node2D melhorMina = null;

		foreach (Node node in minas)
		{
			if (node is not Node2D mina)
				continue;

			if (!mina.HasMethod("esta_disponivel_para_npc"))
				continue;

			if (!mina.HasMethod("reservar_para_npc"))
				continue;

			bool disponivel = mina.Call(
				"esta_disponivel_para_npc", npc
			).AsBool();

			if (!disponivel)
				continue;

			float distancia = npc.GlobalPosition.DistanceTo(
				mina.GlobalPosition
			);

			if (distancia < menorDistancia)
			{
				menorDistancia = distancia;
				melhorMina = mina;
			}
		}

		if (melhorMina == null)
			return;

		// Tenta reservar a mina antes de caminhar até ela.
		bool reservou = melhorMina.Call(
			"reservar_para_npc", npc
		).AsBool();

		if (!reservou)
			return;

		minaAlvo = melhorMina;
		npc.IsGoingToMine = true;
		npc.targetNav = minaAlvo.GlobalPosition;

		GD.Print("NPC escolheu e reservou a mina: ", minaAlvo.Name);
	}

	private void ProcessarMina(float delta)
	{
		if (!GodotObject.IsInstanceValid(minaAlvo))
		{
			FinalizarMineracao();
			return;
		}

		bool esgotada = minaAlvo.Get("esgotada").AsBool();

		// A mina pode ter sido esgotada pelo próprio jogador.
		if (esgotada)
		{
			FinalizarMineracao();
			return;
		}

		// Ainda está caminhando até a mina.
		if (!npc.IsMining)
		{
			npc.targetNav = minaAlvo.GlobalPosition;

			float distancia = npc.GlobalPosition.DistanceTo(
				minaAlvo.GlobalPosition
			);

			if (distancia <= DistanciaParaMinerar)
			{
				npc.BeginMining();
				tempoAtaque = 0f;

				GD.Print("NPC chegou e começou a minerar: ", minaAlvo.Name);
			}

			return;
		}

		// Já está minerando: aplica dano em intervalos.
		tempoAtaque += delta;

		if (tempoAtaque >= IntervaloAtaque)
		{
			tempoAtaque = 0f;

			var gameManager = GetNode<Node>("/root/GameManager");

			int multiplicadorDano = gameManager.Get("multiplicador_dano_npcs").AsInt32();
			int multiplicadorFortuna = gameManager.Get("multiplicador_fortuna_npcs").AsInt32();

			// Calcula os atributos finais do NPC.
			int danoFinal = DanoPorAtaque * multiplicadorDano;
			int fortunaFinal = npc.FortunaMineracao * multiplicadorFortuna;

			// Aplica o dano e a fortuna na mina.
			minaAlvo.Call("receber_dano", danoFinal, fortunaFinal);

			// Verifica novamente porque o ataque pode ter esgotado a mina.
			if (GodotObject.IsInstanceValid(minaAlvo) &&
				minaAlvo.Get("esgotada").AsBool())
			{
				FinalizarMineracao();
			}
		}
	}

	private void FinalizarMineracao()
	{
		if (npc != null)
		{
			npc.EndMining();
			npc.IsGoingToMine = false;
			npc.targetNav = null;
		}

		LiberarReserva();

		minaAlvo = null;
		tempoAtaque = 0f;
		aguardandoNovaAcao = true;

		GD.Print("NPC finalizou a mineração e liberou a mina.");
	}

	private void LiberarReserva()
	{
		if (GodotObject.IsInstanceValid(minaAlvo) &&
			minaAlvo.HasMethod("liberar_reserva_npc"))
		{
			minaAlvo.Call("liberar_reserva_npc", npc);
		}
	}

	public override void _ExitTree()
	{
		LiberarReserva();

		if (npc != null)
		{
			npc.EndMining();
			npc.IsGoingToMine = false;
		}
	}
}
