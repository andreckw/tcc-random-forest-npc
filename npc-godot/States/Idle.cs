using Godot;

namespace States
{
    public class Idle : IActionState
    {
        public void Act(Node node)
        {
            GD.Print("Agindo em IDLE");
        }
    }
}