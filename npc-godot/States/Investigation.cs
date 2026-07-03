using Godot;

namespace States
{
    public class Investigation : IActionState
    {
        public void Act(Node node)
        {
            GD.Print("Agindo em Investigation");
        }
    }
}