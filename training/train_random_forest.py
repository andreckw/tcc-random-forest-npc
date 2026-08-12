"""Treina, compara e exporta cinco perfis de Random Forest para os NPCs.

O script pode consumir o CSV coletado pela Godot ou gerar uma base sintética que
repete a política da árvore de decisão usada como baseline no projeto.
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import numpy as np
import onnxruntime as ort
import pandas as pd
from joblib import dump
from onnx.defs import onnx_opset_version
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
)
from sklearn.model_selection import StratifiedGroupKFold, StratifiedKFold, train_test_split

FEATURE_ORDER = [
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
    "trait_openness_exp",
]

CONTINUOUS_FEATURES = [
    "stamina",
    "hunger",
    "hour",
    "leisure",
    "trait_extraversion",
    "trait_agreeableness",
    "trait_conscientiousness",
    "trait_emotional_stability",
    "trait_openness_exp",
]

CATEGORICAL_VALUES = {
    "socialClass": {0, 1, 2},
    "socialStatus": {0, 1},
    "priority": {0, 1, 2},
}

ID_COLUMN = "npcId"
LABEL_COLUMN = "acao_alvo"
ACTION_NAMES = ["Idle", "PatrolWalk", "Interact", "Investigation", "Aggressive"]
ALL_LABELS = list(range(len(ACTION_NAMES)))

SOCIAL_CLASS_HIGH = 0
SOCIAL_CLASS_AVERAGE = 1
SOCIAL_CLASS_LOW = 2
SOCIAL_STATUS_MARRIED = 0
PRIORITY_FAMILY = 1
PRIORITY_WORK = 2
HOURS_PER_DAY = 24.0

DEFAULT_SAMPLES = 5_000
DEFAULT_NOISE = 0.15
DEFAULT_SEED = 42
DEFAULT_TEST_SIZE = 0.20
DEFAULT_CV_FOLDS = 5
MINIMUM_SAMPLES = 100
TARGET_OPSET = min(17, onnx_opset_version())
RUNTIME_FORMAT_VERSION = 1

SCRIPT_DIR = Path(__file__).resolve().parent
REPOSITORY_DIR = SCRIPT_DIR.parent
DEFAULT_ARTIFACTS_DIR = SCRIPT_DIR / "artifacts"
DEFAULT_RUNTIME_MODELS_DIR = REPOSITORY_DIR / "npc-godot" / "Models"


@dataclass(frozen=True)
class ForestProfile:
    name: str
    strategy: str
    n_estimators: int
    criterion: str
    max_depth: int | None
    min_samples_leaf: int
    max_features: str | float | None
    class_weight: str | None
    bootstrap: bool = True
    max_samples: float | None = None

    def estimator_parameters(self) -> dict[str, Any]:
        return {
            "n_estimators": self.n_estimators,
            "criterion": self.criterion,
            "max_depth": self.max_depth,
            "min_samples_leaf": self.min_samples_leaf,
            "max_features": self.max_features,
            "class_weight": self.class_weight,
            "bootstrap": self.bootstrap,
            "max_samples": self.max_samples,
        }


# Os nomes solicitados identificam configurações reproduzíveis, não pessoas ou
# subconjuntos diferentes do dataset. A ordem também é usada nos relatórios.
FOREST_PROFILES = (
    ForestProfile(
        name="Nicolas",
        strategy="baseline original do repositório, equilibrada e limitada",
        n_estimators=100,
        criterion="gini",
        max_depth=10,
        min_samples_leaf=1,
        max_features="sqrt",
        class_weight="balanced",
    ),
    ForestProfile(
        name="Andre",
        strategy="árvores profundas com ganho de informação por entropia",
        n_estimators=300,
        criterion="entropy",
        max_depth=20,
        min_samples_leaf=1,
        max_features=None,
        class_weight="balanced_subsample",
    ),
    ForestProfile(
        name="Renan",
        strategy="regularização de folhas para reduzir sobreajuste ao ruído",
        n_estimators=300,
        criterion="log_loss",
        max_depth=16,
        min_samples_leaf=2,
        max_features="sqrt",
        class_weight="balanced",
    ),
    ForestProfile(
        name="Luiz",
        strategy="maior diversidade por subamostragem de linhas e atributos",
        n_estimators=350,
        criterion="gini",
        max_depth=18,
        min_samples_leaf=1,
        max_features=0.75,
        class_weight="balanced_subsample",
        max_samples=0.80,
    ),
    ForestProfile(
        name="Victor",
        strategy="alta capacidade, usando todos os atributos em cada divisão",
        n_estimators=500,
        criterion="log_loss",
        max_depth=None,
        min_samples_leaf=1,
        max_features=None,
        class_weight=None,
    ),
)


@dataclass
class DatasetBundle:
    frame: pd.DataFrame
    source: str
    groups: np.ndarray | None
    generation: dict[str, Any] | None


@dataclass
class DataSplit:
    features_train: np.ndarray
    features_test: np.ndarray
    labels_train: np.ndarray
    labels_test: np.ndarray
    groups_train: np.ndarray | None
    groups_test: np.ndarray | None


def leisure_threshold(social_class: np.ndarray) -> np.ndarray:
    return np.select(
        [
            social_class == SOCIAL_CLASS_HIGH,
            social_class == SOCIAL_CLASS_AVERAGE,
            social_class == SOCIAL_CLASS_LOW,
        ],
        [0.35, 0.50, 0.65],
        default=0.50,
    )


def apply_decision_rule(frame: pd.DataFrame, hour_raw: np.ndarray) -> np.ndarray:
    """Espelha a ordem das condições de NpcDecisionTree.cs."""

    stamina = frame["stamina"].to_numpy()
    hunger = frame["hunger"].to_numpy()
    social_class = frame["socialClass"].to_numpy()
    social_status = frame["socialStatus"].to_numpy()
    leisure = frame["leisure"].to_numpy()
    priority = frame["priority"].to_numpy()
    extraversion = frame["trait_extraversion"].to_numpy()
    agreeableness = frame["trait_agreeableness"].to_numpy()
    conscientiousness = frame["trait_conscientiousness"].to_numpy()
    emotional_stability = frame["trait_emotional_stability"].to_numpy()
    openness = frame["trait_openness_exp"].to_numpy()

    starving = hunger > 0.70
    exhausted = stamina < 0.25
    night_time = (hour_raw < 6.0) | (hour_raw > 22.0)
    on_duty = (priority == PRIORITY_WORK) & (conscientiousness >= 0.40) & (stamina > 0.30)
    curious = (openness > 0.60) & (stamina > 0.40)
    sociable = (
        (extraversion > 0.50)
        & (leisure > leisure_threshold(social_class))
        & (
            (social_status == SOCIAL_STATUS_MARRIED)
            | (priority == PRIORITY_FAMILY)
            | (agreeableness > 0.50)
        )
    )
    hostile = (emotional_stability < 0.30) & (agreeableness < 0.40) & (hunger > 0.40)
    dutiful = (conscientiousness >= 0.40) & (stamina > 0.20)

    return np.select(
        [starving, exhausted, night_time, on_duty, curious, sociable, hostile, dutiful],
        [2, 0, 0, 1, 3, 2, 4, 1],
        default=0,
    ).astype(np.int64)


def generate_synthetic_dataset(num_samples: int, noise_rate: float, seed: int) -> DatasetBundle:
    if num_samples < MINIMUM_SAMPLES:
        raise ValueError(f"--samples deve ser pelo menos {MINIMUM_SAMPLES}")
    if not 0.0 <= noise_rate < 1.0:
        raise ValueError("--noise deve estar no intervalo [0, 1)")

    rng = np.random.default_rng(seed)
    hour_raw = rng.uniform(0.0, HOURS_PER_DAY, num_samples)

    frame = pd.DataFrame(
        {
            "stamina": rng.uniform(0.0, 1.0, num_samples),
            "hunger": rng.uniform(0.0, 1.0, num_samples),
            "hour": hour_raw / HOURS_PER_DAY,
            "socialClass": rng.integers(0, 3, num_samples),
            "socialStatus": rng.integers(0, 2, num_samples),
            "leisure": rng.uniform(0.0, 1.0, num_samples),
            "priority": rng.integers(0, 3, num_samples),
            "trait_extraversion": rng.uniform(0.0, 1.0, num_samples),
            "trait_agreeableness": rng.uniform(0.0, 1.0, num_samples),
            "trait_conscientiousness": rng.uniform(0.0, 1.0, num_samples),
            "trait_emotional_stability": rng.uniform(0.0, 1.0, num_samples),
            "trait_openness_exp": rng.uniform(0.0, 1.0, num_samples),
        }
    )

    labels = apply_decision_rule(frame, hour_raw)
    original_labels = labels.copy()
    exploration_mask = rng.random(num_samples) < noise_rate
    labels[exploration_mask] = rng.integers(0, len(ACTION_NAMES), exploration_mask.sum())
    frame[LABEL_COLUMN] = labels

    generation = {
        "samples": num_samples,
        "exploration_rate": noise_rate,
        "exploration_events": int(exploration_mask.sum()),
        "labels_effectively_changed": int(np.count_nonzero(labels != original_labels)),
        "seed": seed,
    }
    source = f"sintético ({num_samples} amostras; exploração {noise_rate:.0%})"
    return DatasetBundle(frame=frame, source=source, groups=None, generation=generation)


def _read_csv_with_supported_separator(path: Path) -> pd.DataFrame:
    with path.open("r", encoding="utf-8-sig") as csv_file:
        header = csv_file.readline()
    separator = ";" if header.count(";") >= header.count(",") else ","
    return pd.read_csv(path, sep=separator, encoding="utf-8-sig")


def validate_dataset(frame: pd.DataFrame, source: str) -> pd.DataFrame:
    required = FEATURE_ORDER + [LABEL_COLUMN]
    missing = [column for column in required if column not in frame.columns]
    if missing:
        raise ValueError(f"dataset {source} não respeita o contrato; colunas ausentes: {missing}")
    if len(frame) < MINIMUM_SAMPLES:
        raise ValueError(
            f"dataset {source} tem {len(frame)} registros; mínimo técnico: {MINIMUM_SAMPLES}"
        )

    validated = frame.copy()
    for column in required:
        validated[column] = pd.to_numeric(validated[column], errors="raise")

    numeric_values = validated[required].to_numpy(dtype=np.float64)
    if not np.isfinite(numeric_values).all():
        raise ValueError(f"dataset {source} contém valor vazio, infinito ou NaN")

    for column in CONTINUOUS_FEATURES:
        invalid = ~validated[column].between(0.0, 1.0, inclusive="both")
        if invalid.any():
            raise ValueError(f"coluna {column} deve ficar entre 0 e 1; {int(invalid.sum())} inválidos")

    for column, allowed in CATEGORICAL_VALUES.items():
        values = validated[column].to_numpy(dtype=np.float64)
        if not np.equal(values, np.floor(values)).all() or not set(values.astype(int)).issubset(allowed):
            raise ValueError(f"coluna {column} aceita somente {sorted(allowed)}")
        validated[column] = validated[column].astype(np.int64)

    labels = validated[LABEL_COLUMN].to_numpy(dtype=np.float64)
    if not np.equal(labels, np.floor(labels)).all() or not set(labels.astype(int)).issubset(ALL_LABELS):
        raise ValueError(f"coluna {LABEL_COLUMN} aceita somente {ALL_LABELS}")
    validated[LABEL_COLUMN] = validated[LABEL_COLUMN].astype(np.int64)

    missing_labels = sorted(set(ALL_LABELS) - set(validated[LABEL_COLUMN].unique()))
    if missing_labels:
        missing_names = [ACTION_NAMES[index] for index in missing_labels]
        raise ValueError(f"dataset não contém exemplos das ações: {missing_names}")

    return validated


def load_collected_dataset(path: Path) -> DatasetBundle:
    if not path.is_file():
        raise ValueError(f"dataset não encontrado: {path}")

    frame = _read_csv_with_supported_separator(path)
    frame = validate_dataset(frame, str(path))
    groups = None
    if ID_COLUMN in frame.columns:
        if frame[ID_COLUMN].isna().any() or (frame[ID_COLUMN].astype(str).str.strip() == "").any():
            raise ValueError(f"coluna {ID_COLUMN} contém identificadores vazios")
        groups = frame[ID_COLUMN].astype(str).to_numpy()

    return DatasetBundle(
        frame=frame,
        source=f"coletado em {path.resolve()} ({len(frame)} amostras)",
        groups=groups,
        generation=None,
    )


def ensure_stratification_is_possible(
    labels: np.ndarray,
    groups: np.ndarray | None,
    folds: int,
    context: str,
) -> None:
    if folds < 2:
        raise ValueError("o número de divisões deve ser pelo menos 2")

    if groups is None:
        counts = np.bincount(labels, minlength=len(ACTION_NAMES))
        scarce = [ACTION_NAMES[index] for index, count in enumerate(counts) if count < folds]
    else:
        scarce = []
        for label, action_name in enumerate(ACTION_NAMES):
            class_groups = np.unique(groups[labels == label])
            if len(class_groups) < folds:
                scarce.append(action_name)

    if scarce:
        raise ValueError(
            f"{context}: as classes {scarce} precisam aparecer em pelo menos {folds} "
            f"{'NPCs distintos' if groups is not None else 'registros'}"
        )


def split_dataset(
    features: np.ndarray,
    labels: np.ndarray,
    groups: np.ndarray | None,
    test_size: float,
    seed: int,
) -> DataSplit:
    if not 0.10 <= test_size <= 0.40:
        raise ValueError("--test-size deve estar entre 0.10 e 0.40")

    if groups is None:
        ensure_stratification_is_possible(labels, None, 2, "separação treino/teste")
        train_indices, test_indices = train_test_split(
            np.arange(len(labels)),
            test_size=test_size,
            random_state=seed,
            stratify=labels,
        )
    else:
        split_count = max(2, round(1.0 / test_size))
        ensure_stratification_is_possible(labels, groups, split_count, "separação por NPC")
        splitter = StratifiedGroupKFold(n_splits=split_count, shuffle=True, random_state=seed)
        candidates = list(splitter.split(features, labels, groups))
        train_indices, test_indices = min(
            candidates,
            key=lambda indices: abs(len(indices[1]) / len(labels) - test_size),
        )
        if set(groups[train_indices]) & set(groups[test_indices]):
            raise RuntimeError("vazamento detectado: um NPC apareceu no treino e no teste")

    return DataSplit(
        features_train=features[train_indices],
        features_test=features[test_indices],
        labels_train=labels[train_indices],
        labels_test=labels[test_indices],
        groups_train=None if groups is None else groups[train_indices],
        groups_test=None if groups is None else groups[test_indices],
    )


def build_model(profile: ForestProfile, seed: int, n_jobs: int) -> RandomForestClassifier:
    return RandomForestClassifier(
        **profile.estimator_parameters(),
        random_state=seed,
        n_jobs=n_jobs,
    )


def score_predictions(labels: np.ndarray, predictions: np.ndarray) -> dict[str, float]:
    return {
        "accuracy": float(accuracy_score(labels, predictions)),
        "balanced_accuracy": float(balanced_accuracy_score(labels, predictions)),
        "f1_macro": float(
            f1_score(labels, predictions, labels=ALL_LABELS, average="macro", zero_division=0)
        ),
    }


def run_cross_validation(
    profile: ForestProfile,
    features: np.ndarray,
    labels: np.ndarray,
    groups: np.ndarray | None,
    folds: int,
    seed: int,
) -> dict[str, Any]:
    ensure_stratification_is_possible(labels, groups, folds, f"validação cruzada de {profile.name}")
    if groups is None:
        splitter: Any = StratifiedKFold(n_splits=folds, shuffle=True, random_state=seed)
        splits: Iterable[tuple[np.ndarray, np.ndarray]] = splitter.split(features, labels)
    else:
        splitter = StratifiedGroupKFold(n_splits=folds, shuffle=True, random_state=seed)
        splits = splitter.split(features, labels, groups)

    fold_scores: list[dict[str, float]] = []
    for fold_index, (train_indices, validation_indices) in enumerate(splits, start=1):
        fold_model = build_model(profile, seed + fold_index, n_jobs=-1)
        fold_model.fit(features[train_indices], labels[train_indices])
        predictions = fold_model.predict(features[validation_indices])
        scores = score_predictions(labels[validation_indices], predictions)
        scores["fold"] = fold_index
        fold_scores.append(scores)

    summary: dict[str, Any] = {"folds": fold_scores}
    for metric in ("accuracy", "balanced_accuracy", "f1_macro"):
        values = np.asarray([fold[metric] for fold in fold_scores])
        summary[f"{metric}_mean"] = float(values.mean())
        summary[f"{metric}_std"] = float(values.std())
    return summary


def evaluate_profile(
    profile: ForestProfile,
    split: DataSplit,
    cv_folds: int,
    seed: int,
) -> tuple[RandomForestClassifier, dict[str, Any]]:
    started = time.perf_counter()
    validation = run_cross_validation(
        profile,
        split.features_train,
        split.labels_train,
        split.groups_train,
        cv_folds,
        seed,
    )

    model = build_model(profile, seed, n_jobs=-1)
    model.fit(split.features_train, split.labels_train)
    predictions = model.predict(split.features_test)
    test_scores = score_predictions(split.labels_test, predictions)

    report = classification_report(
        split.labels_test,
        predictions,
        labels=ALL_LABELS,
        target_names=ACTION_NAMES,
        zero_division=0,
        output_dict=True,
    )

    metrics = {
        "profile": profile.name,
        "strategy": profile.strategy,
        "parameters": profile.estimator_parameters(),
        "cross_validation": validation,
        "test": test_scores,
        "confusion_matrix": confusion_matrix(
            split.labels_test, predictions, labels=ALL_LABELS
        ).tolist(),
        "confusion_matrix_labels": ACTION_NAMES,
        "classification_report": report,
        "feature_importances": {
            name: float(importance)
            for name, importance in zip(FEATURE_ORDER, model.feature_importances_)
        },
        "evaluation_seconds": float(time.perf_counter() - started),
    }
    return model, metrics


def export_onnx(model: RandomForestClassifier, output_path: Path) -> None:
    initial_types = [("float_input", FloatTensorType([None, len(FEATURE_ORDER)]))]
    onnx_model = convert_sklearn(
        model,
        initial_types=initial_types,
        options={id(model): {"zipmap": False}},
        target_opset=TARGET_OPSET,
    )
    output_path.write_bytes(onnx_model.SerializeToString())


def verify_onnx_parity(
    output_path: Path,
    features: np.ndarray,
    sklearn_predictions: np.ndarray,
) -> dict[str, Any]:
    session = ort.InferenceSession(str(output_path), providers=["CPUExecutionProvider"])
    input_name = session.get_inputs()[0].name
    outputs = session.run(None, {input_name: features})
    onnx_predictions = np.asarray(outputs[0]).ravel().astype(np.int64)
    agreement = float(np.mean(onnx_predictions == sklearn_predictions))
    probability_shape = list(np.asarray(outputs[1]).shape)

    if len(probability_shape) != 2 or probability_shape[1] != len(ACTION_NAMES):
        raise RuntimeError(
            f"ONNX gerou probabilidades {probability_shape}; esperado (n, {len(ACTION_NAMES)})"
        )
    if agreement != 1.0:
        raise RuntimeError(f"paridade sklearn/ONNX de {agreement:.6f}; exportação rejeitada")

    return {
        "outputs": [output.name for output in session.get_outputs()],
        "probability_shape": probability_shape,
        "prediction_parity": agreement,
        "target_opset": TARGET_OPSET,
    }


def runtime_document(model: RandomForestClassifier, profile: ForestProfile) -> dict[str, Any]:
    if model.classes_.tolist() != ALL_LABELS:
        raise RuntimeError(
            f"classes do modelo {model.classes_.tolist()} divergem do contrato {ALL_LABELS}"
        )

    def compact_float32(value: float) -> float:
        # Nove algarismos significativos preservam qualquer IEEE-754 float32 e
        # evitam carregar para o JSON os dígitos extras da conversão para double.
        return float(format(np.float32(value), ".9g"))

    trees = []
    for estimator in model.estimators_:
        tree = estimator.tree_
        nodes: list[list[float | int]] = []
        for node_index in range(tree.node_count):
            feature_index = int(tree.feature[node_index])
            if feature_index < 0:
                values = tree.value[node_index][0].astype(float)
                total = float(values.sum())
                probabilities = values / total if total > 0.0 else np.zeros(len(ACTION_NAMES))
                nodes.append([-1, *[compact_float32(value) for value in probabilities]])
            else:
                nodes.append(
                    [
                        feature_index,
                        compact_float32(tree.threshold[node_index]),
                        int(tree.children_left[node_index]),
                        int(tree.children_right[node_index]),
                    ]
                )
        trees.append({"nodes": nodes})

    return {
        "format_version": RUNTIME_FORMAT_VERSION,
        "profile": profile.name,
        "feature_order": FEATURE_ORDER,
        "action_names": ACTION_NAMES,
        "trees": trees,
    }


def predict_runtime_document(document: dict[str, Any], features: np.ndarray) -> np.ndarray:
    predictions = np.empty(len(features), dtype=np.int64)
    for row_index, row in enumerate(features):
        scores = np.zeros(len(ACTION_NAMES), dtype=np.float64)
        for tree in document["trees"]:
            node_index = 0
            while True:
                node = tree["nodes"][node_index]
                feature_index = int(node[0])
                if feature_index < 0:
                    scores += np.asarray(node[1:], dtype=np.float64)
                    break
                node_index = int(node[2] if row[feature_index] <= node[1] else node[3])
        predictions[row_index] = int(np.argmax(scores))
    return predictions


def export_runtime_json(
    model: RandomForestClassifier,
    profile: ForestProfile,
    output_path: Path,
    parity_features: np.ndarray,
) -> dict[str, Any]:
    document = runtime_document(model, profile)
    output_path.write_text(
        json.dumps(document, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    reference = model.predict(parity_features)
    runtime_predictions = predict_runtime_document(document, parity_features)
    agreement = float(np.mean(reference == runtime_predictions))
    if agreement != 1.0:
        output_path.unlink(missing_ok=True)
        raise RuntimeError(f"paridade sklearn/runtime JSON de {agreement:.6f}; exportação rejeitada")

    return {
        "format_version": RUNTIME_FORMAT_VERSION,
        "prediction_parity": agreement,
        "size_bytes": output_path.stat().st_size,
    }


def build_contract() -> dict[str, Any]:
    return {
        "feature_order": FEATURE_ORDER,
        "label_column": LABEL_COLUMN,
        "id_column": ID_COLUMN,
        "action_names": ACTION_NAMES,
        "input_tensor": "float_input",
        "input_dtype": "float32",
        "continuous_range": [0.0, 1.0],
        "categorical_ordinals": {
            "socialClass": {"HIGH": 0, "AVERAGE": 1, "LOW": 2},
            "socialStatus": {"MARRIED": 0, "SINGLE": 1},
            "priority": {"SELF": 0, "FAMILY": 1, "WORK": 2},
        },
    }


def distribution(labels: np.ndarray) -> dict[str, int]:
    counts = np.bincount(labels, minlength=len(ACTION_NAMES))
    return {name: int(counts[index]) for index, name in enumerate(ACTION_NAMES)}


def comparison_row(metrics: dict[str, Any]) -> dict[str, Any]:
    validation = metrics["cross_validation"]
    test = metrics["test"]
    return {
        "profile": metrics["profile"],
        "strategy": metrics["strategy"],
        "cv_accuracy_mean": validation["accuracy_mean"],
        "cv_accuracy_std": validation["accuracy_std"],
        "cv_balanced_accuracy_mean": validation["balanced_accuracy_mean"],
        "cv_f1_macro_mean": validation["f1_macro_mean"],
        "test_accuracy": test["accuracy"],
        "test_balanced_accuracy": test["balanced_accuracy"],
        "test_f1_macro": test["f1_macro"],
        "evaluation_seconds": metrics["evaluation_seconds"],
    }


def select_winner(rows: list[dict[str, Any]]) -> str:
    # O conjunto de teste não participa da seleção. F1 macro só desempata a
    # acurácia de validação e evita favorecer classes majoritárias em um empate.
    winner = max(
        rows,
        key=lambda row: (row["cv_accuracy_mean"], row["cv_f1_macro_mean"]),
    )
    return str(winner["profile"])


def write_summary_markdown(
    output_path: Path,
    source: str,
    rows: list[dict[str, Any]],
    winner_name: str,
    split: DataSplit,
    seed: int,
    cv_folds: int,
) -> None:
    lines = [
        "# Resultado da comparação das Random Forests",
        "",
        f"- Fonte: {source}",
        f"- Seed: {seed}",
        f"- Treino: {len(split.labels_train)} registros",
        f"- Teste final: {len(split.labels_test)} registros",
        f"- Validação cruzada: {cv_folds} folds apenas no conjunto de treino",
        f"- Vencedor pela acurácia média de validação: **{winner_name}**",
        "",
        "| Perfil | Acurácia CV | Acurácia teste | Acurácia balanceada | F1 macro |",
        "|---|---:|---:|---:|---:|",
    ]
    for row in rows:
        lines.append(
            "| {profile} | {cv_accuracy_mean:.4f} ± {cv_accuracy_std:.4f} | "
            "{test_accuracy:.4f} | {test_balanced_accuracy:.4f} | {test_f1_macro:.4f} |".format(
                **row
            )
        )
    lines.extend(
        [
            "",
            "O teste foi compartilhado por todos os perfis somente para comparação. "
            "A escolha do vencedor não utilizou esses resultados, reduzindo viés de seleção.",
            "",
        ]
    )
    output_path.write_text("\n".join(lines), encoding="utf-8")


def print_comparison(rows: list[dict[str, Any]], winner_name: str) -> None:
    print()
    print("perfil    acurácia CV       acurácia teste   acur. balanceada   F1 macro")
    print("-" * 79)
    for row in rows:
        marker = "*" if row["profile"] == winner_name else " "
        print(
            f"{marker}{row['profile']:<9} "
            f"{row['cv_accuracy_mean']:.4f} ± {row['cv_accuracy_std']:.4f}    "
            f"{row['test_accuracy']:.4f}           "
            f"{row['test_balanced_accuracy']:.4f}              "
            f"{row['test_f1_macro']:.4f}"
        )
    print(f"\n* vencedor selecionado pela acurácia média da validação: {winner_name}")


def train_suite(args: argparse.Namespace) -> dict[str, Any]:
    output_dir: Path = args.out.resolve()
    runtime_dir: Path = args.runtime_out.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    runtime_dir.mkdir(parents=True, exist_ok=True)

    if args.dataset is None:
        bundle = generate_synthetic_dataset(args.samples, args.noise, args.seed)
        bundle.frame.to_csv(output_dir / "dataset_sintetico.csv", sep=";", index=False)
    else:
        bundle = load_collected_dataset(args.dataset)

    bundle.frame = validate_dataset(bundle.frame, bundle.source)
    features = bundle.frame[FEATURE_ORDER].to_numpy(dtype=np.float32)
    labels = bundle.frame[LABEL_COLUMN].to_numpy(dtype=np.int64)
    split = split_dataset(features, labels, bundle.groups, args.test_size, args.seed)
    ensure_stratification_is_possible(
        split.labels_train,
        split.groups_train,
        args.cv_folds,
        "validação cruzada",
    )

    selected_names = {name.casefold() for name in args.profiles}
    profiles = [profile for profile in FOREST_PROFILES if profile.name.casefold() in selected_names]
    unknown = selected_names - {profile.name.casefold() for profile in FOREST_PROFILES}
    if unknown:
        raise ValueError(f"perfis desconhecidos: {sorted(unknown)}")
    if not profiles:
        raise ValueError("selecione pelo menos um perfil")

    print(f"fonte: {bundle.source}")
    print(f"distribuição: {distribution(labels)}")
    print(f"treino/teste: {len(split.labels_train)}/{len(split.labels_test)}")
    if bundle.groups is not None:
        print(
            f"separação por NPC: {len(np.unique(split.groups_train))} no treino; "
            f"{len(np.unique(split.groups_test))} no teste"
        )

    metrics_by_name: dict[str, dict[str, Any]] = {}
    rows: list[dict[str, Any]] = []
    for index, profile in enumerate(profiles, start=1):
        print(f"[{index}/{len(profiles)}] avaliando {profile.name}: {profile.strategy}...")
        model, metrics = evaluate_profile(profile, split, args.cv_folds, args.seed)
        metrics_by_name[profile.name] = metrics
        rows.append(comparison_row(metrics))

    winner_name = select_winner(rows)
    contract = build_contract()
    (output_dir / "feature_contract.json").write_text(
        json.dumps(contract, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    for index, profile in enumerate(profiles, start=1):
        print(f"[{index}/{len(profiles)}] exportando {profile.name}...")
        profile_dir = output_dir / "models" / profile.name
        profile_dir.mkdir(parents=True, exist_ok=True)

        # Modelos de produção usam todos os registros depois da avaliação honesta.
        production_model = build_model(profile, args.seed, n_jobs=-1)
        production_model.fit(features, labels)
        production_predictions = production_model.predict(split.features_test)

        joblib_path = profile_dir / "model.joblib"
        onnx_path = profile_dir / "model.onnx"
        runtime_path = profile_dir / "model.runtime.json"
        dump(production_model, joblib_path)
        export_onnx(production_model, onnx_path)
        onnx_metadata = verify_onnx_parity(
            onnx_path, split.features_test, production_predictions
        )
        runtime_metadata = export_runtime_json(
            production_model, profile, runtime_path, split.features_test
        )

        addon_runtime_path = runtime_dir / f"{profile.name}.json"
        shutil.copyfile(runtime_path, addon_runtime_path)

        metrics = metrics_by_name[profile.name]
        metrics["artifacts"] = {
            "joblib": str(joblib_path),
            "onnx": str(onnx_path),
            "runtime_json": str(runtime_path),
            "addon_runtime_json": str(addon_runtime_path),
        }
        metrics["onnx"] = onnx_metadata
        metrics["runtime"] = runtime_metadata
        metrics["production_refit_samples"] = int(len(labels))
        (profile_dir / "metrics.json").write_text(
            json.dumps(metrics, ensure_ascii=False, indent=2), encoding="utf-8"
        )

    comparison_frame = pd.DataFrame(rows)
    comparison_frame.to_csv(output_dir / "comparison.csv", index=False)
    comparison_payload = {
        "source": bundle.source,
        "generation": bundle.generation,
        "seed": args.seed,
        "test_size_requested": args.test_size,
        "cv_folds": args.cv_folds,
        "samples": int(len(labels)),
        "train_samples": int(len(split.labels_train)),
        "test_samples": int(len(split.labels_test)),
        "class_distribution": distribution(labels),
        "group_aware_split": bundle.groups is not None,
        "selection_rule": "maior cv_accuracy_mean; cv_f1_macro_mean como desempate",
        "winner": winner_name,
        "profiles": rows,
    }
    (output_dir / "comparison.json").write_text(
        json.dumps(comparison_payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    write_summary_markdown(
        output_dir / "RESULTADOS.md",
        bundle.source,
        rows,
        winner_name,
        split,
        args.seed,
        args.cv_folds,
    )
    (runtime_dir / "selected_profile.txt").write_text(winner_name + "\n", encoding="utf-8")

    print_comparison(rows, winner_name)
    print(f"artefatos: {output_dir}")
    print(f"modelos para a Godot: {runtime_dir}")
    return comparison_payload


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Compara cinco perfis de Random Forest para os NPCs do TCC."
    )
    parser.add_argument("--dataset", type=Path, default=None, help="CSV coletado pela Godot")
    parser.add_argument("--samples", type=int, default=DEFAULT_SAMPLES)
    parser.add_argument("--noise", type=float, default=DEFAULT_NOISE)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--test-size", type=float, default=DEFAULT_TEST_SIZE)
    parser.add_argument("--cv-folds", type=int, default=DEFAULT_CV_FOLDS)
    parser.add_argument("--out", type=Path, default=DEFAULT_ARTIFACTS_DIR)
    parser.add_argument("--runtime-out", type=Path, default=DEFAULT_RUNTIME_MODELS_DIR)
    parser.add_argument(
        "--profiles",
        nargs="+",
        default=[profile.name for profile in FOREST_PROFILES],
        metavar="NOME",
        help="perfis a executar (padrão: os cinco)",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        train_suite(args)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"erro: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
