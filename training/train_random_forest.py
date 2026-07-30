import argparse
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
import pandas as pd
from joblib import dump
from onnx.defs import onnx_opset_version
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.model_selection import StratifiedKFold, cross_val_score, train_test_split

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

LABEL_COLUMN = "acao_alvo"

ACTION_NAMES = ["Idle", "PatrolWalk", "Interact", "Investigation", "Aggressive"]

SOCIAL_CLASS_HIGH = 0
SOCIAL_CLASS_AVERAGE = 1
SOCIAL_CLASS_LOW = 2

SOCIAL_STATUS_MARRIED = 0

PRIORITY_FAMILY = 1
PRIORITY_WORK = 2

HOURS_PER_DAY = 24.0

N_ESTIMATORS = 100
MAX_DEPTH = 10
CLASS_WEIGHT = "balanced"
CV_FOLDS = 5
TARGET_OPSET = min(17, onnx_opset_version())


def leisure_threshold(social_class):
    return np.select(
        [
            social_class == SOCIAL_CLASS_HIGH,
            social_class == SOCIAL_CLASS_AVERAGE,
            social_class == SOCIAL_CLASS_LOW,
        ],
        [0.35, 0.5, 0.65],
        default=0.5,
    )


def apply_decision_rule(frame, hour_raw):
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

    starving = hunger > 0.7
    exhausted = stamina < 0.25
    night_time = (hour_raw < 6.0) | (hour_raw > 22.0)
    on_duty = (priority == PRIORITY_WORK) & (conscientiousness >= 0.4) & (stamina > 0.3)
    curious = (openness > 0.6) & (stamina > 0.4)
    sociable = (
        (extraversion > 0.5)
        & (leisure > leisure_threshold(social_class))
        & (
            (social_status == SOCIAL_STATUS_MARRIED)
            | (priority == PRIORITY_FAMILY)
            | (agreeableness > 0.5)
        )
    )
    hostile = (emotional_stability < 0.3) & (agreeableness < 0.4) & (hunger > 0.4)
    dutiful = (conscientiousness >= 0.4) & (stamina > 0.2)

    return np.select(
        [starving, exhausted, night_time, on_duty, curious, sociable, hostile, dutiful],
        [2, 0, 0, 1, 3, 2, 4, 1],
        default=0,
    ).astype(np.int64)


def generate_synthetic_dataset(num_samples, noise_rate, seed):
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

    noise_mask = rng.random(num_samples) < noise_rate
    labels[noise_mask] = rng.integers(0, len(ACTION_NAMES), noise_mask.sum())

    frame[LABEL_COLUMN] = labels
    return frame, int(noise_mask.sum())


def load_collected_dataset(path):
    frame = pd.read_csv(path, sep=";")
    missing = [column for column in FEATURE_ORDER + [LABEL_COLUMN] if column not in frame.columns]

    if missing:
        raise SystemExit(f"dataset em {path} nao respeita o contrato, colunas ausentes: {missing}")

    return frame[FEATURE_ORDER + [LABEL_COLUMN]]


def train(frame, seed):
    features = frame[FEATURE_ORDER].to_numpy(dtype=np.float32)
    labels = frame[LABEL_COLUMN].to_numpy(dtype=np.int64)

    features_train, features_test, labels_train, labels_test = train_test_split(
        features,
        labels,
        test_size=0.2,
        random_state=seed,
        stratify=labels,
    )

    model = RandomForestClassifier(
        n_estimators=N_ESTIMATORS,
        max_depth=MAX_DEPTH,
        class_weight=CLASS_WEIGHT,
        random_state=seed,
        n_jobs=-1,
    )
    model.fit(features_train, labels_train)

    folds = StratifiedKFold(n_splits=CV_FOLDS, shuffle=True, random_state=seed)
    cv_scores = cross_val_score(model, features_train, labels_train, cv=folds, n_jobs=-1)

    predictions = model.predict(features_test)

    present = sorted(set(labels_test.tolist()) | set(predictions.tolist()))
    report = classification_report(
        labels_test,
        predictions,
        labels=present,
        target_names=[ACTION_NAMES[index] for index in present],
        zero_division=0,
        output_dict=True,
    )

    metrics = {
        "samples": int(len(frame)),
        "accuracy": float(accuracy_score(labels_test, predictions)),
        "cv_mean": float(cv_scores.mean()),
        "cv_std": float(cv_scores.std()),
        "confusion_matrix": confusion_matrix(labels_test, predictions, labels=present).tolist(),
        "confusion_matrix_labels": present,
        "class_distribution": {
            ACTION_NAMES[index]: int(count)
            for index, count in zip(*np.unique(labels, return_counts=True))
        },
        "feature_importances": {
            name: float(importance)
            for name, importance in zip(FEATURE_ORDER, model.feature_importances_)
        },
        "classification_report": report,
    }

    return model, features_test, predictions, metrics


def export_onnx(model, output_path):
    initial_types = [("float_input", FloatTensorType([None, len(FEATURE_ORDER)]))]

    onnx_model = convert_sklearn(
        model,
        initial_types=initial_types,
        options={id(model): {"zipmap": False}},
        target_opset=TARGET_OPSET,
    )

    output_path.write_bytes(onnx_model.SerializeToString())


def verify_onnx_parity(output_path, features_test, sklearn_predictions):
    session = ort.InferenceSession(str(output_path), providers=["CPUExecutionProvider"])
    input_name = session.get_inputs()[0].name
    outputs = session.run(None, {input_name: features_test})

    onnx_predictions = np.asarray(outputs[0]).ravel().astype(np.int64)
    agreement = float(np.mean(onnx_predictions == sklearn_predictions))

    output_names = [output.name for output in session.get_outputs()]
    probability_shape = np.asarray(outputs[1]).shape

    if len(probability_shape) != 2 or probability_shape[1] != len(ACTION_NAMES):
        raise SystemExit(
            f"saida de probabilidades com shape {probability_shape}, esperado (n, {len(ACTION_NAMES)}); "
            "verifique se zipmap=False foi aplicado"
        )

    if agreement < 1.0:
        raise SystemExit(f"paridade sklearn/ONNX de apenas {agreement:.6f}, exportacao rejeitada")

    return {
        "onnx_outputs": output_names,
        "probability_shape": list(probability_shape),
        "parity": agreement,
        "target_opset": TARGET_OPSET,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", type=Path, default=None)
    parser.add_argument("--samples", type=int, default=2000)
    parser.add_argument("--noise", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out", type=Path, default=Path(__file__).parent / "artifacts")
    args = parser.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)

    if args.dataset is None:
        frame, injected = generate_synthetic_dataset(args.samples, args.noise, args.seed)
        source = f"sintetico ({args.samples} amostras, ruido {args.noise:.0%}, {injected} rotulos alterados)"
        frame.to_csv(args.out / "dataset_sintetico.csv", sep=";", index=False)
    else:
        frame = load_collected_dataset(args.dataset)
        source = f"coletado em {args.dataset} ({len(frame)} amostras)"
        injected = None

    print(f"fonte: {source}")

    model, features_test, predictions, metrics = train(frame, args.seed)

    onnx_path = args.out / "rf_npc_model.onnx"
    export_onnx(model, onnx_path)
    parity = verify_onnx_parity(onnx_path, features_test, predictions)

    dump(model, args.out / "rf_npc_model.joblib")

    contract = {
        "feature_order": FEATURE_ORDER,
        "label_column": LABEL_COLUMN,
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
    (args.out / "feature_contract.json").write_text(json.dumps(contract, indent=2), encoding="utf-8")

    metrics["source"] = source
    metrics["noise_rate"] = args.noise
    metrics["injected_labels"] = injected
    metrics["onnx"] = parity
    (args.out / "metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")

    print()
    print(f"acuracia (holdout)     : {metrics['accuracy']:.4f}")
    print(f"validacao cruzada {CV_FOLDS}x  : {metrics['cv_mean']:.4f} +/- {metrics['cv_std']:.4f}")
    print(f"distribuicao de classes: {metrics['class_distribution']}")
    print()
    print("importancia das features:")
    for name, importance in sorted(metrics["feature_importances"].items(), key=lambda item: -item[1]):
        print(f"  {name:<28} {importance:.4f}")
    print()
    print("matriz de confusao:")
    for row in metrics["confusion_matrix"]:
        print("  " + " ".join(f"{value:5d}" for value in row))
    print()
    print(f"saidas ONNX            : {parity['onnx_outputs']}")
    print(f"shape probabilidades   : {parity['probability_shape']}")
    print(f"paridade sklearn/ONNX  : {parity['parity']:.6f}")
    print(f"opset                  : {parity['target_opset']}")
    print()
    print(f"artefatos em {args.out}")


if __name__ == "__main__":
    main()
