using Godot;
namespace States
{
    public class Investigation : IActionState
    {
        private const float Intensity = 1.2f;

        public void Act(NpcAgent npc, float delta)
        {
            if (npc.targetNav == null)
            {
                var screenSize = npc.GetViewportRect().Size;
                int posX = (int)GD.RandRange(50, screenSize.X - 50);
                int posY = (int)GD.RandRange(50, screenSize.Y - 50);

                npc.targetNav = new Vector2(posX, posY);
            }

            npc.ApplyMetabolism(delta);
            npc.SpendStamina(delta, Intensity);
            npc.AccumulateLeisureNeed(delta);


            Vector2 direction = ((Vector2)npc.targetNav - npc.GlobalPosition).Normalized();
            npc.Velocity = direction * 40f;
            npc.MoveAndSlide();
        }
    }
}
