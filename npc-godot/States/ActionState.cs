using Godot;

namespace States
{
    public interface IActionState
    {
        public void Act(Node node);
    }
}