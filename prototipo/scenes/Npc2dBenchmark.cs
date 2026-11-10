using AlgorithmsNpc.RandomForestNpc;
using Godot;
using System;
using System.Diagnostics;

public partial class Npc2dBenchmark : NpcRandomForest
{

    protected override int DecideAction()
    {
        Stopwatch stopwatch = Stopwatch.StartNew();
        int action = base.DecideAction();
        stopwatch.Stop();
        if (GetTree().CurrentScene.HasMethod("adicionar_inferencia")) {
            TimeSpan time = TimeSpan.FromTicks(stopwatch.ElapsedTicks); 
            GetTree().CurrentScene.Call("adicionar_inferencia", time.TotalMilliseconds, action);
        }
        return action;
    }

}
