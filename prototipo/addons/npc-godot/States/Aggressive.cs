using Godot;
namespace States
{
	public class Aggressive : IActionState{
		private Vector2 direction = Vector2.Zero;

		public void Act(NpcDecisionTree npc, float delta, Node node){
			npc.ConsumirRecusros(delta);
			var sprite = npc.GetNode<AnimatedSprite2D>("AnimatedSprite2D");

			if (direction == Vector2.Zero){
				direction = new Vector2(
					(float)GD.RandRange(-1, 1),
					(float)GD.RandRange(-1, 1)
				).Normalized();
			}

			var screenSize = npc.GetViewportRect().Size;
			if (npc.Position.X < 0 || npc.Position.X > screenSize.X){
				direction.X = -direction.X;
			}
			if (npc.Position.Y < 0 || npc.Position.Y > screenSize.Y){
				direction.Y = -direction.Y;
			}

			npc.Velocity = direction * 120f;
			npc.MoveAndSlide();
			sprite.Play("walk");
		}
	}
}
