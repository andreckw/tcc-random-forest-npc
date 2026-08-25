
using System.Collections.Generic;
using System.IO;
using Godot;

namespace AlgorithmsNpc
{
    public class SalvarDataset
    {
        private static SalvarDataset instance;

        public List<string> linhas;
        private readonly string path = "addons/npc-godot/AlgorithmsNpc/DecisionTreeNpc/dataset.csv";

        private SalvarDataset()
        {
            linhas = [];
            File.WriteAllText(path, "socialClass; priority; socialStatus; stamina; hunger; leisure; extraversion; agreableness; conscientiouness; emotionalStability; opennesExp; actualState\n");
        }

        public static SalvarDataset GetInstance()
        {
            return instance ??= new SalvarDataset();
        }

        public void InsertLinha(NpcDecisionTree npc)
        {
            File.AppendAllText(path, $"{npc.socialClass}; {npc.priority}; {npc.socialStatus}; {npc.stamina}; {npc.hunger}; {npc.leisure}; {npc.trait.extraversion}; {npc.trait.agreableness}; {npc.trait.emotionalStability}; {npc.trait.opennesExp}; {npc.state.GetType().Name}\n");
        }
    }
}