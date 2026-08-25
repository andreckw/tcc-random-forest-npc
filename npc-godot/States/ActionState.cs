namespace States
{
    public interface IActionState
    {
        void Act(NpcAgent npc, float delta);
    }
}
