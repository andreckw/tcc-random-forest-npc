using System;
using Godot;

[Tool]
[GlobalClass]
public partial class Trait : Resource
{
    [Export(PropertyHint.Range, "0,1")]
    public float extraversion = 0;
    [Export(PropertyHint.Range, "0,1")]
    public float agreeableness = 0;
    [Export(PropertyHint.Range, "0,1")]
    public float conscientiousness = 0;
    [Export(PropertyHint.Range, "0,1")]
    public float emotionalStability = 0;
    [Export(PropertyHint.Range, "0,1")]
    public float opennessExp = 0;
    [Export]
    public bool alwaysRandomizer = false;

    public void RandomTraits(Random rng)
    {
        extraversion = rng.NextSingle();
        agreeableness = rng.NextSingle();
        conscientiousness = rng.NextSingle();
        emotionalStability = rng.NextSingle();
        opennessExp = rng.NextSingle();
    }
}
