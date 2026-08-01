using Godot;

namespace States
{
	public class Aggressive : IActionState
	{
		public void Act(NpcDecisionTree npc, float delta, Node node)
		{
			
			npc.ConsumirRecusros(delta);

			npc.PlayAnimation("walk_aggressive");

			// procura o npc mais prox
			NpcDecisionTree alvo = npc.GetNearestNpc();

			
			if (alvo != null)
			{
				float distancia = npc.Position.DistanceTo(alvo.Position);
		
				if (distancia <= 30f)
				{
					alvo.Die();

					npc.Velocity = Vector2.Zero;
					npc.MoveAndSlide();
				}
				else
				{
					npc.MoveTowards(alvo.Position, 120f);
				}
			}
		}
	}
}
