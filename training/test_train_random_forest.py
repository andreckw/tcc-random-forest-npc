import tempfile
import unittest
from dataclasses import replace
from pathlib import Path

import numpy as np

import train_random_forest as pipeline


class RandomForestPipelineTests(unittest.TestCase):
    def test_profiles_have_requested_names_and_distinct_parameters(self):
        names = [profile.name for profile in pipeline.FOREST_PROFILES]
        parameters = [profile.estimator_parameters() for profile in pipeline.FOREST_PROFILES]

        self.assertEqual(names, ["Nicolas", "Andre", "Renan", "Luiz", "Victor"])
        self.assertEqual(len({repr(value) for value in parameters}), 5)

    def test_synthetic_dataset_is_reproducible_and_respects_contract(self):
        first = pipeline.generate_synthetic_dataset(500, 0.15, 42)
        second = pipeline.generate_synthetic_dataset(500, 0.15, 42)

        self.assertTrue(first.frame.equals(second.frame))
        self.assertEqual(
            list(first.frame.columns),
            pipeline.FEATURE_ORDER + [pipeline.LABEL_COLUMN],
        )
        self.assertTrue(set(first.frame[pipeline.LABEL_COLUMN]).issubset(pipeline.ALL_LABELS))
        pipeline.validate_dataset(first.frame, "teste")

    def test_validation_rejects_out_of_range_feature(self):
        bundle = pipeline.generate_synthetic_dataset(500, 0.15, 42)
        bundle.frame.loc[0, "stamina"] = 1.5

        with self.assertRaisesRegex(ValueError, "stamina"):
            pipeline.validate_dataset(bundle.frame, "teste")

    def test_winner_selection_does_not_use_test_accuracy(self):
        rows = [
            {
                "profile": "Nicolas",
                "cv_accuracy_mean": 0.90,
                "cv_f1_macro_mean": 0.80,
                "test_accuracy": 0.10,
            },
            {
                "profile": "Andre",
                "cv_accuracy_mean": 0.89,
                "cv_f1_macro_mean": 0.99,
                "test_accuracy": 1.00,
            },
        ]

        self.assertEqual(pipeline.select_winner(rows), "Nicolas")

    def test_group_split_does_not_leak_npc_between_sets(self):
        bundle = pipeline.generate_synthetic_dataset(500, 0.15, 42)
        features = bundle.frame[pipeline.FEATURE_ORDER].to_numpy(dtype=np.float32)
        labels = bundle.frame[pipeline.LABEL_COLUMN].to_numpy(dtype=np.int64)
        groups = np.asarray([f"npc-{index}" for index in range(len(labels))])

        split = pipeline.split_dataset(features, labels, groups, test_size=0.20, seed=42)

        self.assertTrue(set(split.groups_train).isdisjoint(set(split.groups_test)))
        self.assertEqual(len(split.labels_train) + len(split.labels_test), 500)

    def test_runtime_json_predictions_match_sklearn(self):
        bundle = pipeline.generate_synthetic_dataset(500, 0.10, 7)
        features = bundle.frame[pipeline.FEATURE_ORDER].to_numpy(dtype=np.float32)
        labels = bundle.frame[pipeline.LABEL_COLUMN].to_numpy(dtype=np.int64)
        profile = replace(pipeline.FOREST_PROFILES[0], n_estimators=15, max_depth=8)
        model = pipeline.build_model(profile, seed=7, n_jobs=1)
        model.fit(features, labels)

        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "runtime.json"
            metadata = pipeline.export_runtime_json(model, profile, path, features[:100])

        self.assertEqual(metadata["prediction_parity"], 1.0)


if __name__ == "__main__":
    unittest.main()
