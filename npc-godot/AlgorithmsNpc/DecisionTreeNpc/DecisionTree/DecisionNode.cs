using States;

namespace DecisionTree
{
    public interface IDecisionNode
    {
        IActionState Evaluate(NpcAgent npc);
    }
}
