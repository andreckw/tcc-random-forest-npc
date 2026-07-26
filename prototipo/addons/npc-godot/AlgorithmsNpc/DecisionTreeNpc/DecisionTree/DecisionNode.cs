using Godot;

namespace DecisionTree {
    public interface IDecisionNode
    {
        public abstract IDecisionNode Evalute(NpcDecisionTree npc);
    }
}