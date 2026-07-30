namespace States
{
    public class PatrolWalk : IActionState
    {
        private const float Intensity = 1.0f;

        public void Act(NpcAgent npc, float delta)
        {
            npc.ApplyMetabolism(delta);
            npc.SpendStamina(delta, Intensity);
            npc.AccumulateLeisureNeed(delta);
        }
    }
}
