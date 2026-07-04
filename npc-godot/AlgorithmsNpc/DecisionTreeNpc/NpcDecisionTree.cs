using System;
using System.Collections.Generic;
using DecisionTree;
using Godot;
using States;
using Util;

[Tool]
[GlobalClass]
public partial class NpcDecisionTree : CharacterBody2D
{

    private IDecisionNode rootNode;

    public IActionState state;
    public IActionState ultimoState;

    [Export]
    public Trait trait;
    [Export]
    public Timer timer;
    [Export]
    public SocialClass socialClass;
    [Export]
    public Priority priority;
    [Export]
    public SocialStatus socialStatus;
    [Export(PropertyHint.Range, "0,1")]
    public float stamina = 1;
    [Export(PropertyHint.Range, "0,1")]
    public float leisure = 0;
    [Export(PropertyHint.Range, "0,1")]
    public float hunger = 1;

    public void ChangeState()
    {
        createDecisionTree();
        rootNode.Evalute(this);
        timer.Start();
    }

    private void createDecisionTree()
    {
        if (rootNode != null) return;

        ActionNode agressiveState = new(new Aggressive());
        ActionNode idleState = new(new Idle());
        ActionNode interactState = new(new Interact());
        ActionNode InvestigationState = new(new Investigation());
        ActionNode walkState = new(new PatrolWalk());

        Func<NpcDecisionTree, bool> walkCondition = npc => npc.trait.conscientiouness >= 0.4 && npc.stamina > 0.2;
        Func<NpcDecisionTree, bool> agressiveCondition = npc => npc.trait.emotionalStability < 0.3 && npc.hunger < 0.7;
        Func<NpcDecisionTree, bool> interactCondition = npc => npc.trait.extraversion > 0.5 && npc.leisure < 0.7;
        Func<NpcDecisionTree, bool> investigationCondition = npc => npc.trait.opennesExp > 0.6 && npc.stamina > 0.4;

        var conditionWalk = new ConditionNode(walkCondition, walkState, idleState);
        var conditionAgressive = new ConditionNode(agressiveCondition, agressiveState, conditionWalk);
        var conditionInteract = new ConditionNode(interactCondition, interactState, conditionAgressive);
        rootNode = new ConditionNode(investigationCondition, InvestigationState, conditionInteract);
    }


    public override void _Ready()
    {
        base._Ready();

        state = new Idle();

        timer ??= new Timer();
        trait ??= new Trait();

        timer.Timeout += ChangeState;
        timer.Start();
    }

    public override void _PhysicsProcess(double delta)
    {
        base._PhysicsProcess(delta);
        state.Act(this);
    }
}