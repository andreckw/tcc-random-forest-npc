using Godot;

namespace States
{
    public class PatrolWalk : IActionState
    {
        public void Act(Node node)
        {
            GD.Print("Agindo em PatrolWalk");
        }
    }
}