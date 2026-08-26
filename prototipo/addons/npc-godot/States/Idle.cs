using Godot;
namespace States
{
    public class Idle : IActionState
    {
        public void Act(NpcAgent npc, float delta)
        {
            npc.ApplyMetabolism(delta);
            npc.RestoreStamina(delta);
            npc.AccumulateLeisureNeed(delta);

            npc.Velocity = Vector2.Zero;
			npc.MoveAndSlide();
        }
    }
}
