using Godot;
using States;

namespace DecisionTree
{
    public class ActionNode(IActionState actionState) : IDecisionNode
    {
        private IActionState actionState = actionState;

        public IDecisionNode Evalute(NpcDecisionTree npc)
        {
            npc.ultimoState = npc.state;
            npc.state = actionState;
            return this;
        }
    }
}