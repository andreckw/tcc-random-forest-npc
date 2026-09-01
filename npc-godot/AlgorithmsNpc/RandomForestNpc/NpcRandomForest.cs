using Godot;

namespace AlgorithmsNpc.RandomForestNpc
{

    [Tool]
    [GlobalClass]
    public partial class NpcRandomForest : NpcAgent
    {
        [Export]
        public RandomForestProfile modelProfile = RandomForestProfile.Victor;

        [Export(PropertyHint.File, "*.json")]
        public string customModelPath = "";

        private RuntimeRandomForest model;

        protected override int DecideAction()
        {
            model ??= RuntimeRandomForest.Load(ResolveModelPath());
            return model.Predict(BuildFeatureVector());
        }

        private string ResolveModelPath()
        {
            if (!string.IsNullOrWhiteSpace(customModelPath))
            {
                return customModelPath;
            }

            return $"res://addons/npc-godot/Models/{modelProfile}.json";
        }
    }
}
