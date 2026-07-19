using Godot;

namespace States
{
    public class Aggressive : IActionState
    {
        public void Act(NpcDecisionTree npc, float delta, Node node)
        {
            GD.Print("Agindo em Aggressive");
            npc.ConsumirRecusros(delta);
        }
    }
}