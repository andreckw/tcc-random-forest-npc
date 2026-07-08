using System;
using Godot;

[Tool]
[GlobalClass]
public partial class Trait : Resource
{
    [Export(PropertyHint.Range, "0,1")]
    public float extraversion = 0;
    [Export(PropertyHint.Range, "0,1")]
    public float agreableness = 0;
    [Export(PropertyHint.Range, "0,1")]
    public float conscientiouness = 0;
    [Export(PropertyHint.Range, "0,1")]
    public float emotionalStability = 0;
    [Export(PropertyHint.Range, "0,1")]
    public float opennesExp = 0;

    public void randomTraits()
    {
        var rand = new Random();
        extraversion = rand.NextSingle();
        agreableness = rand.NextSingle();
        conscientiouness = rand.NextSingle();
        emotionalStability = rand.NextSingle();
        opennesExp = rand.NextSingle();
    }
}