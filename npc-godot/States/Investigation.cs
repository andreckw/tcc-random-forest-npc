namespace States
{
    public class Investigation : IActionState
    {
        private const float Intensity = 1.2f;

        public void Act(NpcAgent npc, float delta)
        {
            npc.ApplyMetabolism(delta);
            npc.SpendStamina(delta, Intensity);
            npc.AccumulateLeisureNeed(delta);
        }
    }
}
