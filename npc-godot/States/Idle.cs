using Godot;

namespace States
{
    public class Idle : IActionState
    {
        public void Act(NpcDecisionTree npc, float delta, Node node)
        {
            GD.Print("Agindo em IDLE");
            npc.RestaurarRecusros(delta);
        }
    }
}