using Godot;

namespace States
{
    public class Interact : IActionState
    {
        public void Act(Node node)
        {
            GD.Print("Agindo em Interact");
        }
    }
}