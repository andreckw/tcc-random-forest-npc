
using System;
using AlgorithmsNpc;
using Godot;
using States;
using Util;

public abstract partial class NpcAgent : CharacterBody2D
{
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
	public float hunger = 0;

	[Export(PropertyHint.Range, "0,1")]
	public float leisure = 0;

	[Export(PropertyHint.Range, "0,1,0.001")]
	public float staminaDrainRate = 0.02f;

	[Export(PropertyHint.Range, "0,1,0.001")]
	public float staminaRecoveryRate = 0.05f;

	[Export(PropertyHint.Range, "0,1,0.001")]
	public float hungerGrowthRate = 0.015f;

	[Export(PropertyHint.Range, "0,1,0.001")]
	public float hungerSatiationRate = 0.08f;

	[Export(PropertyHint.Range, "0,1,0.001")]
	public float leisureGrowthRate = 0.01f;

	[Export(PropertyHint.Range, "0,1,0.001")]
	public float leisureSatisfactionRate = 0.06f;

	[Export(PropertyHint.Range, "0,1,0.01")]
	public float explorationRate = 0.15f;

	[Export]
	public int randomSeed = 0;

	public string NpcId { get; private set; }

	public IActionState CurrentState { get; private set; }

	public bool IsMining { get; private set; } = false;

	public bool IsGoingToMine { get; set; } = false;

	public float Hour => WorldClock.Hour;

	[Export]
	public AnimatedSprite2D Sprite { get; set; }

	[Export]
	public int Speed = 200;

	[Export]
	public bool PodeMinerar = false;
	
	[Export(PropertyHint.Range, "1,10,1")]
	public int FortunaMineracao { get; set; } = 1;

	public Vector2? targetNav;

	[Export]
	public bool GerarDataset = false;

	protected Random rng;

	public override void _Ready()
	{
		base._Ready();

		NpcId = Guid.NewGuid().ToString();
		rng = randomSeed == 0 ? new Random() : new Random(randomSeed);
		CurrentState = ActionCatalog.FromIndex(0);

		if (Engine.IsEditorHint())
		{
			SetPhysicsProcess(false);
			SetProcess(false);
			return;
		}

		if (trait == null)
		{
			trait = new Trait();
			trait.RandomTraits(rng);
		}
		else
		{
			trait = (Trait)trait.Duplicate();
		}

		timer = timer == null ? new TimerResource() : (TimerResource)timer.Duplicate();

		timer.OnTimeout += ChangeState;
		timer.Start();
	}

	public override void _ExitTree()
	{
		base._ExitTree();

		if (Engine.IsEditorHint())
		{
			return;
		}

		timer.OnTimeout -= ChangeState;
		SalvarDataset.GetInstance().Flush();
	}

	public override void _Process(double delta)
	{
		if (!IsMining && !IsGoingToMine)
		{
			timer.Update((float)delta);
		}
	}

	public override void _PhysicsProcess(double delta)
	{
		base._PhysicsProcess(delta);
		
		AtualizarCorPorEstado();
		
		if (IsMining)
		{
			Velocity = Vector2.Zero;
			MoveAndSlide();
			return;
		}

		if (IsGoingToMine && targetNav != null)
		{
			Vector2 direcao = ((Vector2)targetNav - GlobalPosition).Normalized();

			Velocity = direcao * 80f;

			AtualizarAnimacaoMovimento(direcao);

			MoveAndSlide();
			return;
		}

		CurrentState.Act(this, (float)delta);
	}

	protected abstract int DecideAction();

	public float[] BuildFeatureVector()
	{
		return
		[
			stamina,
			hunger,
			WorldClock.NormalizedHour,
			(int)socialClass,
			(int)socialStatus,
			leisure,
			(int)priority,
			trait.extraversion,
			trait.agreeableness,
			trait.conscientiousness,
			trait.emotionalStability,
			trait.opennessExp
		];
	}

	public void ApplyMetabolism(float delta)
	{
		hunger = Clamp01(hunger + hungerGrowthRate * delta);
	}

	public void SpendStamina(float delta, float intensity)
	{
		stamina = Clamp01(stamina - staminaDrainRate * intensity * delta);
	}

	public void RestoreStamina(float delta)
	{
		stamina = Clamp01(stamina + staminaRecoveryRate * delta);
	}

	public void Eat(float delta)
	{
		hunger = Clamp01(hunger - hungerSatiationRate * delta);
	}

	public void AccumulateLeisureNeed(float delta)
	{
		leisure = Clamp01(leisure + leisureGrowthRate * delta);
	}

	public void SatisfyLeisureNeed(float delta)
	{
		leisure = Clamp01(leisure - leisureSatisfactionRate * delta);
	}

	private void ChangeState()
	{
		if (IsMining)
			return;

		if (trait.alwaysRandomizer)
		{
			trait.RandomTraits(rng);
		}

		targetNav = null;

		int action = DecideAction();

		if (rng.NextSingle() < explorationRate)
		{
			action = rng.Next(ActionCatalog.Count);
		}

		CurrentState = ActionCatalog.FromIndex(action);

		AtualizarCorPorEstado();
		
		if (GerarDataset)
		{
			SalvarDataset.GetInstance().InsertLinha(this, action);
		}

		timer.Start();
	}

	public void AtualizarCorPorEstado()
	{
		if (Sprite == null)
			return;

		if (CurrentState is Aggressive)
		{
			Sprite.Modulate = Color.FromHsv(0, 1, 1);
		}
		else if (CurrentState is Interact)
		{
			Sprite.Modulate = new Color("5caff4ff");
		}
		else if (CurrentState is Investigation)
		{
			Sprite.Modulate = Color.FromHsv(0.33f, 1, 1);
		}
		else
		{
			// Idle e PatrolWalk preservam a aparência original.
			Sprite.Modulate = Colors.White;
		}
	}
	private static float Clamp01(float value)
	{
		if (value < 0f)
		{
			return 0f;
		}

		return value > 1f ? 1f : value;
	}

	public NpcAgent GetNearestNpc()
	{
		float menorDistancia = float.MaxValue;
		NpcAgent maisProximo = null;

		foreach (Node filho in GetParent().GetChildren())
		{
			if (filho == this)
				continue;

			if (filho is NpcAgent npc)
			{
				float distancia = Position.DistanceTo(npc.Position);

				if (distancia < menorDistancia)
				{
					menorDistancia = distancia;
					maisProximo = npc;
				}
			}
		}

		return maisProximo;
	}

	public void AtualizarAnimacaoMovimento(Vector2 direcao)
	{
		if (Sprite == null || IsMining)
			return;

		string animacao;

		// NPC parado
		if (direcao.LengthSquared() < 0.01f)
		{
			animacao = "idle";
		}
		// Diagonais inferiores
		else if (direcao.Y > 0.35f && direcao.X > 0.35f)
		{
			animacao = "walk_down_right";
		}
		else if (direcao.Y > 0.35f && direcao.X < -0.35f)
		{
			animacao = "walk_down_left";
		}
		// Direções horizontais
		else if (Math.Abs(direcao.X) > Math.Abs(direcao.Y))
		{
			animacao = direcao.X > 0 ? "walk_right" : "walk_left";
		}
		// Direções verticais
		else
		{
			animacao = direcao.Y < 0 ? "walk_up" : "walk_down";
		}

		if (Sprite.SpriteFrames != null &&
			Sprite.SpriteFrames.HasAnimation(animacao) &&
			Sprite.Animation != animacao)
		{
			Sprite.Play(animacao);
		}
	}

	public void BeginMining()
	{
		if (IsMining)
			return;

		IsGoingToMine = false;
		IsMining = true;
		targetNav = null;
		Velocity = Vector2.Zero;

		if (Sprite != null)
		{
			Sprite.Play("mine");
		}

		GD.Print("NPC começou a minerar: ", NpcId);
	}

	public void EndMining()
	{
		if (!IsMining)
			return;

		IsMining = false;
		IsGoingToMine = false;
		targetNav = null;

		if (Sprite != null)
		{
			Sprite.Play("idle");
		}

		GD.Print("NPC terminou a mineração: ", NpcId);
	}
}
