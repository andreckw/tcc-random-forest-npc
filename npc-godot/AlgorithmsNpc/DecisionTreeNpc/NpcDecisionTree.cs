using System;
using DecisionTree;
using Godot;
using States;
using Util;

[Tool]
[GlobalClass]
public partial class NpcDecisionTree : NpcAgent
{
    private IDecisionNode rootNode;

    protected override int DecideAction()
    {
        rootNode ??= BuildTree();
        return ActionCatalog.ToIndex(rootNode.Evaluate(this));
    }

    private static IDecisionNode BuildTree()
    {
        ActionNode idle = new(ActionCatalog.FromIndex(0));
        ActionNode patrol = new(ActionCatalog.FromIndex(1));
        ActionNode interact = new(ActionCatalog.FromIndex(2));
        ActionNode investigation = new(ActionCatalog.FromIndex(3));
        ActionNode aggressive = new(ActionCatalog.FromIndex(4));

        Func<NpcAgent, bool> starving = npc => npc.hunger > 0.7f;
        Func<NpcAgent, bool> exhausted = npc => npc.stamina < 0.25f;
        Func<NpcAgent, bool> nightTime = npc => npc.Hour < 6f || npc.Hour > 22f;
        Func<NpcAgent, bool> onDuty = npc => npc.priority == Priority.WORK
            && npc.trait.conscientiousness >= 0.4f
            && npc.stamina > 0.3f;
        Func<NpcAgent, bool> curious = npc => npc.trait.opennessExp > 0.6f && npc.stamina > 0.4f;
        Func<NpcAgent, bool> sociable = npc => npc.trait.extraversion > 0.5f
            && npc.leisure > LeisureThreshold(npc.socialClass)
            && (npc.socialStatus == SocialStatus.MARRIED
                || npc.priority == Priority.FAMILY
                || npc.trait.agreeableness > 0.5f);
        Func<NpcAgent, bool> hostile = npc => npc.trait.emotionalStability < 0.3f
            && npc.trait.agreeableness < 0.4f
            && npc.hunger > 0.4f;
        Func<NpcAgent, bool> dutiful = npc => npc.trait.conscientiousness >= 0.4f && npc.stamina > 0.2f;

        ConditionNode dutifulNode = new(dutiful, patrol, idle);
        ConditionNode hostileNode = new(hostile, aggressive, dutifulNode);
        ConditionNode sociableNode = new(sociable, interact, hostileNode);
        ConditionNode curiousNode = new(curious, investigation, sociableNode);
        ConditionNode onDutyNode = new(onDuty, patrol, curiousNode);
        ConditionNode nightNode = new(nightTime, idle, onDutyNode);
        ConditionNode exhaustedNode = new(exhausted, idle, nightNode);

        return new ConditionNode(starving, interact, exhaustedNode);
    }

    private static float LeisureThreshold(SocialClass socialClass)
    {
        return socialClass switch
        {
            SocialClass.HIGH => 0.35f,
            SocialClass.AVERAGE => 0.5f,
            SocialClass.LOW => 0.65f,
            _ => 0.5f
        };
    }

    public override void _Process(double delta)
    {
        base._Process(delta);
		var label = GetNodeOrNull<Label>("StateLabel");
		if (label != null && label.Visible){
			label.Text = CurrentState.GetType().Name;
		}
    }

	// private void OnAreaInputEvent(Node viewport, InputEvent inputEvent, long shapeIdx){
		
	// 	if (inputEvent is InputEventMouseButton mouseEvent && mouseEvent.Pressed){
	// 		var label = GetNodeOrNull<Label>("StateLabel");
	// 		if (label != null){
	// 			label.Text = CurrentState.GetType().Name;
	// 			label.Visible = !label.Visible;
	// 		}
	// 		EmitSignal(SignalName.NpcClicked, this);
	// 	}
	// }
}