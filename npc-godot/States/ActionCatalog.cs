using System;

namespace States
{
    public static class ActionCatalog
    {
        public const int Count = AlgorithmsNpc.NpcFeatureContract.ActionCount;

        private static readonly IActionState[] catalog =
        [
            new Idle(),
            new PatrolWalk(),
            new Interact(),
            new Investigation(),
            new Aggressive()
        ];

        public static IActionState FromIndex(int index)
        {
            if (index < 0 || index >= Count)
            {
                throw new ArgumentOutOfRangeException(nameof(index), index, $"ação fora do contrato 0..{Count - 1}");
            }

            return catalog[index];
        }

        public static int ToIndex(IActionState state)
        {
            for (int i = 0; i < Count; i++)
            {
                if (catalog[i].GetType() == state.GetType())
                {
                    return i;
                }
            }

            throw new ArgumentException($"estado {state.GetType().Name} não pertence ao contrato de ações", nameof(state));
        }

        public static string NameFromIndex(int index)
        {
            return FromIndex(index).GetType().Name;
        }
    }
}
