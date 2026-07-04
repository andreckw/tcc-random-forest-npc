using System;
using Godot;

namespace DecisionTree
{
    public class ConditionNode(Func<NpcDecisionTree, bool> condition, IDecisionNode trueNode, IDecisionNode falseNode) : IDecisionNode
    {
        private Func<NpcDecisionTree, bool> condition = condition;
        private IDecisionNode trueNode = trueNode;
        private IDecisionNode falseNode = falseNode;

        public IDecisionNode Evalute(NpcDecisionTree npc)
        {
            return condition(npc) ? trueNode.Evalute(npc) : falseNode.Evalute(npc);
        }
    }
}