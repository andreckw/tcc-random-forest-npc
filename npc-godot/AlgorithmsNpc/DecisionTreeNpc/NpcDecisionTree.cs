using System;
using System.Collections.Generic;
using AlgorithmsNpc;
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
    public TimerResource timer;
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
        CreateDecisionTree();
        if (trait.alwaysRandomizer)
        {
            trait.RandomTraits();
        }
        rootNode.Evalute(this);
        SalvarDataset.GetInstance().InsertLinha(this);
        timer.Start();
    }

    private void CreateDecisionTree()
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
    }

    public override void _PhysicsProcess(double delta)
    {
        base._PhysicsProcess(delta);
        state.Act(this, (float) delta, null);
    }
}