using Godot;

namespace States
{
    public class Interact : IActionState
    {
        public void Act(NpcDecisionTree npc, float delta, Node node)
        {
            GD.Print("Agindo em Interact");
            npc.ConsumirRecusros(delta);
        }
    }
}