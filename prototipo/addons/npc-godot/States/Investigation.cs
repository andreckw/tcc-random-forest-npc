using Godot;
namespace States
{
	public class Investigation : IActionState{
		private Vector2 direction = Vector2.Zero;
		private float tempoMudanca = 0f;

		public void Act(NpcDecisionTree npc, float delta, Node node){
			npc.ConsumirRecusros(delta);
			var sprite = npc.GetNode<AnimatedSprite2D>("AnimatedSprite2D");

			tempoMudanca -= delta;
			if (tempoMudanca <= 0f){
				direction = new Vector2(
					(float)GD.RandRange(-1.0, 1.0),
					(float)GD.RandRange(-1.0, 1.0)
				).Normalized();
				tempoMudanca = 3f;
			}

			var screenSize = npc.GetViewportRect().Size;
			if (npc.Position.X < 0 || npc.Position.X > screenSize.X){
				direction.X = -direction.X;
			}
			if (npc.Position.Y < 0 || npc.Position.Y > screenSize.Y){
				direction.Y = -direction.Y;
			}

			npc.Velocity = direction * 40f;
			npc.MoveAndSlide();
			
			// comporta
			//npc.SetColor(Colors.Yellow);
			npc.PlayAnimation("idle");
		}
	}
}
