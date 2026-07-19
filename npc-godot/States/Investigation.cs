using Godot;

namespace States
{
    public class Investigation : IActionState
    {
        public void Act(NpcDecisionTree npc, float delta, Node node)
        {
            GD.Print("Agindo em Investigation");
            npc.ConsumirRecusros(delta);
        }
    }
}