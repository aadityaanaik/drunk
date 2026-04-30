"""
Train a Random Forest drink-gesture classifier on OPPORTUNITY data and
export it as a CoreML model for Apple Watch.

Run prepare_data.py first, then:
  python train.py

Output:
  ../Watch/DrinkGestureClassifier.mlmodel  — add this to your Xcode project
"""

from pathlib import Path

import coremltools as ct
import numpy as np
from imblearn.over_sampling import SMOTE
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report
from sklearn.model_selection import train_test_split

# ── Config ────────────────────────────────────────────────────────────────────

DATA_DIR   = Path("data")
MODEL_OUT  = Path("../Watch/DrinkGestureClassifier.mlmodel")

WINDOW_SIZE = 50
N_CHANNELS  = 6   # RLA accel XYZ + gyro XYZ
# Statistical features extracted per channel
STAT_NAMES  = ["mean", "std", "min", "max", "p25", "p75", "rms"]
N_FEATURES  = N_CHANNELS * len(STAT_NAMES)   # 42

# ── Feature extraction ────────────────────────────────────────────────────────

def extract_features(X_raw: np.ndarray) -> np.ndarray:
    """
    Convert raw windows [n, WINDOW_SIZE * N_CHANNELS] → statistical features
    [n, N_FEATURES]. Must match the extraction in DrinkClassifier.swift exactly.
    """
    n = X_raw.shape[0]
    windows = X_raw.reshape(n, WINDOW_SIZE, N_CHANNELS)
    out = np.empty((n, N_FEATURES), dtype=np.float32)
    for i, w in enumerate(windows):
        feats = []
        for ch in range(N_CHANNELS):
            col = w[:, ch]
            feats += [
                col.mean(),
                col.std(),
                col.min(),
                col.max(),
                np.percentile(col, 25),
                np.percentile(col, 75),
                np.sqrt(np.mean(col ** 2)),   # RMS
            ]
        out[i] = feats
    return out


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print("Loading data...")
    X_raw = np.load(DATA_DIR / "X.npy")
    y     = np.load(DATA_DIR / "y.npy")

    print("Extracting statistical features...")
    X = extract_features(X_raw)

    print("Balancing classes with SMOTE...")
    X_bal, y_bal = SMOTE(random_state=42).fit_resample(X, y)
    print(f"  After SMOTE — drink: {(y_bal == 'drink').sum()}, "
          f"other: {(y_bal == 'other').sum()}")

    X_train, X_test, y_train, y_test = train_test_split(
        X_bal, y_bal, test_size=0.2, random_state=42, stratify=y_bal
    )

    print(f"Training RandomForest on {len(X_train)} windows...")
    clf = RandomForestClassifier(
        n_estimators=150, max_depth=20, random_state=42, n_jobs=-1
    )
    clf.fit(X_train, y_train)

    print("\nClassification report (test set):")
    print(classification_report(y_test, clf.predict(X_test)))

    # ── CoreML export ─────────────────────────────────────────────────────────
    print(f"Exporting CoreML model → {MODEL_OUT} ...")
    feature_names = [
        f"{stat}_{ch}"
        for ch in ["ax", "ay", "az", "gx", "gy", "gz"]
        for stat in STAT_NAMES
    ]
    model = ct.converters.sklearn.convert(
        clf,
        input_features=feature_names,
        output_feature_names=["label"],
    )
    model.short_description = (
        "Drink gesture classifier trained on OPPORTUNITY dataset wrist IMU data. "
        "Input: 42 statistical features from a 1-second, 50 Hz window of "
        "RLA accel XYZ + gyro XYZ. Output: 'drink' or 'other'."
    )
    model.save(str(MODEL_OUT))
    print("Done. Add DrinkGestureClassifier.mlmodel to your Xcode Watch target.")


if __name__ == "__main__":
    main()
