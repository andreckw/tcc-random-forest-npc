using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Godot;

namespace AlgorithmsNpc
{
    public sealed record DatasetSample
    {
        [JsonPropertyName("npcId")] public string NpcId { get; init; } = string.Empty;
        [JsonPropertyName("socialClass")] public int SocialClass { get; init; }
        [JsonPropertyName("priority")] public int Priority { get; init; }
        [JsonPropertyName("socialStatus")] public int SocialStatus { get; init; }
        [JsonPropertyName("stamina")] public float Stamina { get; init; }
        [JsonPropertyName("hunger")] public float Hunger { get; init; }
        [JsonPropertyName("leisure")] public float Leisure { get; init; }
        [JsonPropertyName("trait_extraversion")] public float TraitExtraversion { get; init; }
        [JsonPropertyName("trait_agreeableness")] public float TraitAgreeableness { get; init; }
        [JsonPropertyName("trait_conscientiousness")] public float TraitConscientiousness { get; init; }
        [JsonPropertyName("trait_emotional_stability")] public float TraitEmotionalStability { get; init; }
        [JsonPropertyName("trait_openness_exp")] public float TraitOpennessExp { get; init; }
        [JsonPropertyName("actualState")] public string ActualState { get; init; } = string.Empty;
    }

    public sealed class SalvarDataset
    {
        public const string CsvHeader = "npcId;socialClass;priority;socialStatus;stamina;hunger;leisure;trait_extraversion;trait_agreeableness;trait_conscientiousness;trait_emotional_stability;trait_openness_exp;actualState";

        private const int FlushThreshold = 50;
        private const char Separator = ';';
        private const string LineEnding = "\n";

        private static readonly Encoding Utf8NoBom = new UTF8Encoding(false);

        private static SalvarDataset instance;

        private readonly object gate = new();
        private readonly List<DatasetSample> pending = [];
        private readonly List<DatasetSample> persisted = [];
        private readonly string csvPath;
        private readonly string jsonPath;
        private readonly JsonSerializerOptions jsonOptions = new() { WriteIndented = false };

        private SalvarDataset()
        {
            csvPath = ProjectSettings.GlobalizePath("user://dataset.csv");
            jsonPath = ProjectSettings.GlobalizePath("user://dataset.json");

            if (!File.Exists(csvPath))
            {
                File.WriteAllText(csvPath, CsvHeader + LineEnding, Utf8NoBom);
            }

            if (File.Exists(jsonPath))
            {
                string existing = File.ReadAllText(jsonPath, Utf8NoBom);
                if (existing.Length > 0)
                {
                    persisted.AddRange(JsonSerializer.Deserialize<List<DatasetSample>>(existing) ?? []);
                }
            }

            AppDomain.CurrentDomain.ProcessExit += OnProcessExit;
        }

        public static SalvarDataset GetInstance()
        {
            return instance ??= new SalvarDataset();
        }

        public int PendingCount
        {
            get { lock (gate) { return pending.Count; } }
        }

        public string CsvPath => csvPath;

        public string JsonPath => jsonPath;

        public void InsertLinha(NpcDecisionTree npc)
        {
            DatasetSample sample = new()
            {
                NpcId = npc.NpcId,
                SocialClass = (int)npc.socialClass,
                Priority = (int)npc.priority,
                SocialStatus = (int)npc.socialStatus,
                Stamina = npc.stamina,
                Hunger = npc.hunger,
                Leisure = npc.leisure,
                TraitExtraversion = npc.trait.extraversion,
                TraitAgreeableness = npc.trait.agreableness,
                TraitConscientiousness = npc.trait.conscientiouness,
                TraitEmotionalStability = npc.trait.emotionalStability,
                TraitOpennessExp = npc.trait.opennesExp,
                ActualState = npc.state.GetType().Name
            };

            bool shouldFlush;
            lock (gate)
            {
                pending.Add(sample);
                shouldFlush = pending.Count >= FlushThreshold;
            }

            if (shouldFlush)
            {
                Flush();
            }
        }

        public static string ToCsvLine(DatasetSample sample)
        {
            CultureInfo invariant = CultureInfo.InvariantCulture;

            return string.Join(Separator,
                sample.NpcId,
                sample.SocialClass.ToString(invariant),
                sample.Priority.ToString(invariant),
                sample.SocialStatus.ToString(invariant),
                sample.Stamina.ToString(invariant),
                sample.Hunger.ToString(invariant),
                sample.Leisure.ToString(invariant),
                sample.TraitExtraversion.ToString(invariant),
                sample.TraitAgreeableness.ToString(invariant),
                sample.TraitConscientiousness.ToString(invariant),
                sample.TraitEmotionalStability.ToString(invariant),
                sample.TraitOpennessExp.ToString(invariant),
                sample.ActualState);
        }

        public void Flush()
        {
            List<DatasetSample> batch;
            lock (gate)
            {
                if (pending.Count == 0)
                {
                    return;
                }

                batch = [.. pending];
            }

            try
            {
                StringBuilder csv = new();
                foreach (DatasetSample sample in batch)
                {
                    csv.Append(ToCsvLine(sample)).Append(LineEnding);
                }

                File.AppendAllText(csvPath, csv.ToString(), Utf8NoBom);

                string json;
                lock (gate)
                {
                    persisted.AddRange(batch);
                    pending.RemoveRange(0, batch.Count);
                    json = JsonSerializer.Serialize(persisted, jsonOptions);
                }

                File.WriteAllText(jsonPath, json, Utf8NoBom);
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException)
            {
                GD.PushError($"SalvarDataset: falha ao gravar o dataset em {csvPath}: {e.Message}");
            }
        }

        private void OnProcessExit(object sender, EventArgs e)
        {
            Flush();
        }
    }
}
