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
        }
    }
}
