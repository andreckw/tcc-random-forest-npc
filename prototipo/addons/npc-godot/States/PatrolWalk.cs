using Godot;
namespace States
{
    public class PatrolWalk : IActionState
    {
        private Vector2 direction = Vector2.Zero;
		private float tempoMudanca = 0f;
        private const float Intensity = 1.0f;

        public void Act(NpcAgent npc, float delta)
        {
            npc.ApplyMetabolism(delta);
            npc.SpendStamina(delta, Intensity);
            npc.AccumulateLeisureNeed(delta);

            tempoMudanca -= delta;
			if (tempoMudanca <= 0f){
				direction = new Vector2(
					(float)GD.RandRange(-1.0, 1.0),
					(float)GD.RandRange(-1.0, 1.0)
				).Normalized();
				tempoMudanca = 2f;
			}

			var screenSize = npc.GetViewportRect().Size;
			if (npc.Position.X < 0 || npc.Position.X > screenSize.X){
				direction.X = -direction.X;
			}
			if (npc.Position.Y < 0 || npc.Position.Y > screenSize.Y){
				direction.Y = -direction.Y;
			}

			npc.Velocity = direction * 80f;
			npc.MoveAndSlide();
        }
    }
}
