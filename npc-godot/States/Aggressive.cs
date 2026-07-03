using Godot;

namespace States
{
    public class Aggressive : IActionState
    {
        public void Act(Node node)
        {
            GD.Print("Agindo em Aggressive");
        }
    }
}