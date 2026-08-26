using System;
using AlgorithmsNpc.RandomForestNpc;
using Godot;

public partial class Npc2dRadomForest : NpcRandomForest
{
    [Export]
    Area2D AreaClickable { get; set; }

    [Export]
    Label Label { get; set; }

    public override void _Ready()
    {
        base._Ready();

        if (AreaClickable != null)
        {
            AreaClickable.InputEvent += OnAreaInputEvent;
        }
    }

    public override void _Process(double delta)
    {
        base._Process(delta);

        if (Label != null)
        {
            Label.Text = CurrentState.GetType().Name;
        }

    }

    private void OnAreaInputEvent(Node viewport, InputEvent inputEvent, long shapeIdx)
    {
        if (inputEvent is InputEventMouseButton mouseEvent && mouseEvent.Pressed)
        {
            if (Label != null)
            {
                Label.Visible = !Label.Visible;
            }
        }
    }
}
