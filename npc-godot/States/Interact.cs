using Godot;
namespace States
{
    public class Interact : IActionState
    {
        private const float Intensity = 0.5f;

        public void Act(NpcAgent npc, float delta)
        {
            npc.ApplyMetabolism(delta);
            npc.Eat(delta);
            npc.SatisfyLeisureNeed(delta);
            npc.SpendStamina(delta, Intensity);
            
            npc.Velocity = Vector2.Zero;
			npc.MoveAndSlide();
        }
    }
}
