using Godot;

namespace States
{
	public class Aggressive : IActionState
	{
		public void Act(NpcDecisionTree npc, float delta, Node node)
		{
			
			npc.ConsumirRecusros(delta);

			
			// npc.SetColor(Colors.Red); // Se quiser usar cor 
			npc.PlayAnimation("walk_aggressive");

			// Procura o NPC mais próximo
			NpcDecisionTree alvo = npc.GetNearestNpc();

			// Se encontrou alguém, vai atrás dele
			if (alvo != null)
			{
				npc.MoveTowards(alvo.Position, 120f);
			}
			else
			{
				// Caso não exista nenhum outro NPC
				npc.Velocity = Vector2.Zero;
				npc.MoveAndSlide();
			}
		}
	}
}
