using System;
using System.Collections.Generic;
using Godot;
using States;
using Util;

[Tool]
[GlobalClass]
public partial class NpcFsm : CharacterBody2D
{
    private Trait _trait;

    private Timer _timer;

    public IActionState state;

    public Trait Trait
    {
        get => _trait;
        set
        {
            _trait = value;
            UpdateConfigurationWarnings();
        }
    }

    public Timer Timer
    {
        get => _timer;
        set
        {
            _timer = value;
            UpdateConfigurationWarnings();
        }
    }

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

    public void ChangeState(int actualGameHour, Node player)
    {
        // TODO Fazer a logica de troca de estado

    }



    private void OnChildEnteredTree(Node node)
    {
        if (node is Trait trait)
        {
            Trait = (Trait)node;
        }

        if (node is Timer timer)
        {
            Timer = (Timer)node;
        }

    }

    private void OnChildExitedTree(Node node)
    {
        if (node is Trait trait)
        {
            Trait = null;
        }

        if (node is Timer timer)
        {
            Timer = null;
        }

    }


    public override void _Ready()
    {
        base._Ready();
        ChildEnteredTree += OnChildEnteredTree;
        ChildExitingTree += OnChildExitedTree;

        state = new Idle();
    }

    public override void _PhysicsProcess(double delta)
    {
        base._PhysicsProcess(delta);
        state.Act(null);
    }

    public override string[] _GetConfigurationWarnings()
    {
        var avisos = new List<String>();

        if (Trait == null)
        {
            avisos.Add("Tem que adicionar uma Trait");
        }

        if (Timer == null)
        {
            avisos.Add("Tem que adicionar um Timer");
        }

        return [.. avisos];
    }
}