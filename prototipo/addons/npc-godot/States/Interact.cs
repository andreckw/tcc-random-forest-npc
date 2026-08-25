using Godot;

namespace States
{
	public class Interact : IActionState
	{
		public void Act(NpcDecisionTree npc, float delta, Node node)
		{
			npc.ConsumirRecusros(delta);
			var sprite = npc.GetNode<AnimatedSprite2D>("AnimatedSprite2D");
			
			npc.Velocity = Vector2.Zero;
			npc.MoveAndSlide();
			sprite.Play("idle");
		}
	}
}
