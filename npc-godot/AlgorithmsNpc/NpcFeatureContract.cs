namespace AlgorithmsNpc
{
    public static class NpcFeatureContract
    {
        public const int FeatureCount = 12;
        public const string IdColumn = "npcId";
        public const string LabelColumn = "acao_alvo";

        public static readonly string[] FeatureNames =
        [
            "stamina",
            "hunger",
            "hour",
            "socialClass",
            "socialStatus",
            "leisure",
            "priority",
            "trait_extraversion",
            "trait_agreeableness",
            "trait_conscientiousness",
            "trait_emotional_stability",
            "trait_openness_exp"
        ];
    }
}
