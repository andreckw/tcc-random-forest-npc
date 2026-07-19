using Godot;

namespace States
{
    public class PatrolWalk : IActionState
    {
        public void Act(NpcDecisionTree npc, float delta, Node node)
        {
            GD.Print("Agindo em PatrolWalk");
            npc.ConsumirRecusros(delta);
        }
    }
}