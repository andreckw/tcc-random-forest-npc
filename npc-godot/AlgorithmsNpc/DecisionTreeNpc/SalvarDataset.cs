using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.Json;
using Godot;

namespace AlgorithmsNpc
{
    public sealed record DatasetSample(string NpcId, float[] Features, int Action);

    public sealed class SalvarDataset
    {
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

        private SalvarDataset()
        {
            csvPath = ProjectSettings.GlobalizePath("user://dataset.csv");
            jsonPath = ProjectSettings.GlobalizePath("user://dataset.json");

            if (!File.Exists(csvPath))
            {
                File.WriteAllText(csvPath, BuildHeader() + LineEnding, Utf8NoBom);
            }

            if (File.Exists(jsonPath))
            {
                persisted.AddRange(ReadJson(jsonPath));
            }

            AppDomain.CurrentDomain.ProcessExit += OnProcessExit;
        }

        public static SalvarDataset GetInstance()
        {
            return instance ??= new SalvarDataset();
        }

        public string CsvPath => csvPath;

        public string JsonPath => jsonPath;

        public int PersistedCount
        {
            get { lock (gate) { return persisted.Count; } }
        }

        public int PendingCount
        {
            get { lock (gate) { return pending.Count; } }
        }

        public static string BuildHeader()
        {
            StringBuilder header = new(NpcFeatureContract.IdColumn);

            foreach (string name in NpcFeatureContract.FeatureNames)
            {
                header.Append(Separator).Append(name);
            }

            return header.Append(Separator).Append(NpcFeatureContract.LabelColumn).ToString();
        }

        public static string ToCsvLine(DatasetSample sample)
        {
            StringBuilder line = new(sample.NpcId);

            foreach (float value in sample.Features)
            {
                line.Append(Separator).Append(value.ToString(CultureInfo.InvariantCulture));
            }

            return line.Append(Separator).Append(sample.Action.ToString(CultureInfo.InvariantCulture)).ToString();
        }

        public void InsertLinha(NpcAgent npc, int action)
        {
            float[] features = npc.BuildFeatureVector();

            if (features.Length != NpcFeatureContract.FeatureCount)
            {
                throw new InvalidOperationException($"vetor de features com {features.Length} posições, contrato exige {NpcFeatureContract.FeatureCount}");
            }

            DatasetSample sample = new(npc.NpcId, features, action);

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

                DatasetSample[] snapshot;
                lock (gate)
                {
                    persisted.AddRange(batch);
                    pending.RemoveRange(0, batch.Count);
                    snapshot = [.. persisted];
                }

                WriteJson(jsonPath, snapshot);
            }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException)
            {
                GD.PushError($"SalvarDataset: falha ao gravar o dataset em {csvPath}: {e.Message}");
            }
        }

        private static void WriteJson(string path, DatasetSample[] samples)
        {
            using FileStream stream = File.Create(path);
            using Utf8JsonWriter writer = new(stream, new JsonWriterOptions { Indented = false });

            writer.WriteStartArray();

            foreach (DatasetSample sample in samples)
            {
                writer.WriteStartObject();
                writer.WriteString(NpcFeatureContract.IdColumn, sample.NpcId);

                for (int i = 0; i < NpcFeatureContract.FeatureCount; i++)
                {
                    writer.WriteNumber(NpcFeatureContract.FeatureNames[i], sample.Features[i]);
                }

                writer.WriteNumber(NpcFeatureContract.LabelColumn, sample.Action);
                writer.WriteEndObject();
            }

            writer.WriteEndArray();
            writer.Flush();
        }

        private static List<DatasetSample> ReadJson(string path)
        {
            List<DatasetSample> samples = [];

            using JsonDocument document = JsonDocument.Parse(File.ReadAllText(path, Utf8NoBom));

            foreach (JsonElement element in document.RootElement.EnumerateArray())
            {
                float[] features = new float[NpcFeatureContract.FeatureCount];

                for (int i = 0; i < NpcFeatureContract.FeatureCount; i++)
                {
                    features[i] = element.GetProperty(NpcFeatureContract.FeatureNames[i]).GetSingle();
                }

                samples.Add(new DatasetSample(
                    element.GetProperty(NpcFeatureContract.IdColumn).GetString(),
                    features,
                    element.GetProperty(NpcFeatureContract.LabelColumn).GetInt32()));
            }

            return samples;
        }

        private void OnProcessExit(object sender, EventArgs e)
        {
            Flush();
        }
    }
}
