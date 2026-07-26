using Godot;

namespace States
{
	public class Idle : IActionState
	{
		public void Act(NpcDecisionTree npc, float delta, Node node)
		{
			npc.RestaurarRecusros(delta);
			npc.Velocity = Vector2.Zero;
			npc.MoveAndSlide();
			var sprite = npc.GetNode<AnimatedSprite2D>("AnimatedSprite2D");
			sprite.Play("idle");
		}
	}
}
