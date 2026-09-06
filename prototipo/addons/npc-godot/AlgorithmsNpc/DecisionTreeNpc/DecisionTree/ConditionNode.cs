using System;
using States;

namespace DecisionTree
{
    public class ConditionNode(Func<NpcAgent, bool> condition, IDecisionNode trueNode, IDecisionNode falseNode) : IDecisionNode
    {
        private readonly Func<NpcAgent, bool> condition = condition;
        private readonly IDecisionNode trueNode = trueNode;
        private readonly IDecisionNode falseNode = falseNode;

        public IActionState Evaluate(NpcAgent npc)
        {
            return condition(npc) ? trueNode.Evaluate(npc) : falseNode.Evaluate(npc);
        }
    }
}
