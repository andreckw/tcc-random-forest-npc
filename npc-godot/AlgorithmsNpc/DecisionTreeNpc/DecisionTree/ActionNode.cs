using States;

namespace DecisionTree
{
    public class ActionNode(IActionState actionState) : IDecisionNode
    {
        private readonly IActionState actionState = actionState;

        public IActionState Evaluate(NpcAgent npc)
        {
            return actionState;
        }
    }
}
