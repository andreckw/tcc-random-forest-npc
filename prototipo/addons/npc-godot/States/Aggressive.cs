using Godot;
namespace States
{
    public class Aggressive : IActionState
    {
        private const float Intensity = 1.5f;

        public void Act(NpcAgent npc, float delta)
        {
            npc.ApplyMetabolism(delta);
            npc.SpendStamina(delta, Intensity);
            npc.AccumulateLeisureNeed(delta);

            npc.Sprite?.Play("walk_aggressive");

            // procura o npc mais prox
            NpcAgent alvo = npc.GetNearestNpc();
            if (alvo != null)
            {
                float distancia = npc.Position.DistanceTo(alvo.Position);

                if (distancia <= 30f)
                {
                    npc.Velocity = Vector2.Zero;
                }
                else
                {
                    Vector2 direction = (alvo.Position - npc.Position).Normalized();

                    npc.Velocity = direction * npc.Speed;

                }
                npc.MoveAndSlide();
            }
        }
    }
}
