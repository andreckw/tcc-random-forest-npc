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

        Func<NpcDecisionTree, bool> walkCondition = npc => npc.trait.conscientiouness >= 0.4 && npc.stamina > 0.2;
        Func<NpcDecisionTree, bool> agressiveCondition = npc => npc.trait.emotionalStability < 0.3 && npc.hunger < 0.7;
        Func<NpcDecisionTree, bool> interactCondition = npc => npc.trait.extraversion > 0.5 && npc.leisure < 0.7;
        Func<NpcDecisionTree, bool> investigationCondition = npc => npc.trait.opennesExp > 0.6 && npc.stamina > 0.4;

        var conditionWalk = new ConditionNode(walkCondition, walkState, idleState);
        var conditionAgressive = new ConditionNode(agressiveCondition, agressiveState, conditionWalk);
        var conditionInteract = new ConditionNode(interactCondition, interactState, conditionAgressive);
        rootNode = new ConditionNode(investigationCondition, InvestigationState, conditionInteract);
    }

    public void ConsumirRecusros(float delta)
    {
        hunger -= delta;
        stamina -= delta;
        leisure += delta;

        if (hunger < 0)
        {
            hunger = 0;
        }

        if (stamina < 0)
        {
            stamina = 0;
        }

        if (leisure > 1)
        {
            leisure = 1;
        }
    }

    public void RestaurarRecusros(float delta)
    {
        hunger += delta;
        stamina += delta;
        leisure -= delta;

        if (hunger > 1)
        {
            hunger = 1;
        }

        if (stamina > 1)
        {
            stamina = 1;
        }

        if (leisure < 0)
        {
            leisure = 0;
        }
    }


    public override void _Ready()
    {
        base._Ready();

        if (Engine.IsEditorHint())
        {
            SetPhysicsProcess(false);
        }

        state = new Idle();

        timer ??= new TimerResource();
        if (trait == null)
        {
            trait = new Trait();
            trait.RandomTraits();
        }

        timer.OnTimeout += ChangeState;
        timer.Start();
    }

    public override void _Process(double delta)
    {
        timer.Update((float)delta);
		var label = GetNodeOrNull<Label>("StateLabel");
		if (label != null && label.Visible){
			label.Text = state.GetType().Name;
		}
    }

    public override void _PhysicsProcess(double delta)
    {
        base._PhysicsProcess(delta);
        state.Act(this, (float) delta, null);
    }

	private void OnAreaInputEvent(Node viewport, InputEvent inputEvent, long shapeIdx){
		
		if (inputEvent is InputEventMouseButton mouseEvent && mouseEvent.Pressed){
			var label = GetNodeOrNull<Label>("StateLabel");
			if (label != null){
				label.Text = state.GetType().Name;
				label.Visible = !label.Visible;
			}
			EmitSignal(SignalName.NpcClicked, this);
		}
	}
}