using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;
using Godot;

namespace AlgorithmsNpc.RandomForestNpc
{
    internal sealed class RuntimeRandomForest
    {
        private const int SupportedFormatVersion = 1;

        private static readonly object CacheGate = new();
        private static readonly Dictionary<string, RuntimeRandomForest> Cache = [];

        private readonly RuntimeTree[] trees;

        private RuntimeRandomForest(RuntimeForestDocument document)
        {
            ValidateDocument(document);
            trees = document.Trees;
            Profile = document.Profile;
        }

        public string Profile { get; }

        public static RuntimeRandomForest Load(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                throw new ArgumentException("o caminho do modelo Random Forest está vazio", nameof(path));
            }

            lock (CacheGate)
            {
                if (Cache.TryGetValue(path, out RuntimeRandomForest cached))
                {
                    return cached;
                }

                RuntimeRandomForest loaded = LoadFromFile(path);
                Cache.Add(path, loaded);
                return loaded;
            }
        }

        private static RuntimeRandomForest LoadFromFile(string path)
        {
            if (!Godot.FileAccess.FileExists(path))
            {
                throw new InvalidOperationException(
                    $"modelo Random Forest não encontrado em {path}; execute training/train_random_forest.py"
                );
            }

            using Godot.FileAccess file = Godot.FileAccess.Open(path, Godot.FileAccess.ModeFlags.Read);
            if (file == null)
            {
                throw new InvalidOperationException(
                    $"não foi possível abrir {path}: {Godot.FileAccess.GetOpenError()}"
                );
            }

            string json = file.GetAsText();
            RuntimeForestDocument document = JsonSerializer.Deserialize<RuntimeForestDocument>(json);
            if (document == null)
            {
                throw new InvalidOperationException($"modelo vazio ou inválido em {path}");
            }

            return new RuntimeRandomForest(document);
        }

        public int Predict(float[] features)
        {
            if (features == null || features.Length != NpcFeatureContract.FeatureCount)
            {
                throw new ArgumentException(
                    $"o modelo exige {NpcFeatureContract.FeatureCount} atributos",
                    nameof(features)
                );
            }

            Span<float> scores = stackalloc float[NpcFeatureContract.ActionCount];
            foreach (RuntimeTree tree in trees)
            {
                AddTreeProbabilities(tree, features, scores);
            }

            int predictedAction = 0;
            for (int action = 1; action < scores.Length; action++)
            {
                if (scores[action] > scores[predictedAction])
                {
                    predictedAction = action;
                }
            }

            return predictedAction;
        }

        private static void AddTreeProbabilities(RuntimeTree tree, float[] features, Span<float> scores)
        {
            int nodeIndex = 0;
            int visitedNodes = 0;

            while (true)
            {
                if (nodeIndex < 0 || nodeIndex >= tree.Nodes.Length)
                {
                    throw new InvalidOperationException("modelo contém índice de nó inválido");
                }
                if (++visitedNodes > tree.Nodes.Length)
                {
                    throw new InvalidOperationException("modelo contém ciclo entre os nós");
                }

                float[] node = tree.Nodes[nodeIndex];
                if (node == null || node.Length == 0)
                {
                    throw new InvalidOperationException("modelo contém nó vazio");
                }

                int featureIndex = (int)node[0];
                if (featureIndex < 0)
                {
                    if (node.Length != NpcFeatureContract.ActionCount + 1)
                    {
                        throw new InvalidOperationException("folha do modelo tem probabilidades inválidas");
                    }

                    for (int action = 0; action < NpcFeatureContract.ActionCount; action++)
                    {
                        scores[action] += node[action + 1];
                    }
                    return;
                }

                if (node.Length != 4 || featureIndex >= features.Length)
                {
                    throw new InvalidOperationException("nó de decisão do modelo é inválido");
                }

                nodeIndex = features[featureIndex] <= node[1] ? (int)node[2] : (int)node[3];
            }
        }

        private static void ValidateDocument(RuntimeForestDocument document)
        {
            if (document.FormatVersion != SupportedFormatVersion)
            {
                throw new InvalidOperationException(
                    $"formato do modelo {document.FormatVersion} não suportado; esperado {SupportedFormatVersion}"
                );
            }
            if (string.IsNullOrWhiteSpace(document.Profile))
            {
                throw new InvalidOperationException("modelo não informa o perfil");
            }
            if (document.Trees == null || document.Trees.Length == 0)
            {
                throw new InvalidOperationException("modelo não contém árvores");
            }

            ValidateContract("atributos", document.FeatureOrder, NpcFeatureContract.FeatureNames);
            ValidateContract("ações", document.ActionNames, NpcFeatureContract.ActionNames);

            foreach (RuntimeTree tree in document.Trees)
            {
                if (tree == null || tree.Nodes == null || tree.Nodes.Length == 0)
                {
                    throw new InvalidOperationException("modelo contém árvore vazia");
                }
            }
        }

        private static void ValidateContract(string description, string[] actual, string[] expected)
        {
            if (actual == null || actual.Length != expected.Length)
            {
                throw new InvalidOperationException($"contrato de {description} incompatível");
            }

            for (int index = 0; index < expected.Length; index++)
            {
                if (!string.Equals(actual[index], expected[index], StringComparison.Ordinal))
                {
                    throw new InvalidOperationException(
                        $"contrato de {description} diverge na posição {index}: " +
                        $"modelo={actual[index]}, plugin={expected[index]}"
                    );
                }
            }
        }
    }

    internal sealed class RuntimeForestDocument
    {
        [JsonPropertyName("format_version")]
        public int FormatVersion { get; set; }

        [JsonPropertyName("profile")]
        public string Profile { get; set; }

        [JsonPropertyName("feature_order")]
        public string[] FeatureOrder { get; set; }

        [JsonPropertyName("action_names")]
        public string[] ActionNames { get; set; }

        [JsonPropertyName("trees")]
        public RuntimeTree[] Trees { get; set; }
    }

    internal sealed class RuntimeTree
    {
        [JsonPropertyName("nodes")]
        public float[][] Nodes { get; set; }
    }
}
