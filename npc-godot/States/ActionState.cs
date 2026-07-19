using Godot;

namespace States
{
    public interface IActionState
    {
        public void Act(NpcDecisionTree npc, float delta, Node node);
    }
}