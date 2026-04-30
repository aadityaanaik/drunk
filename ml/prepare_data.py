"""
Download and preprocess the OPPORTUNITY Activity Recognition dataset.

Produces data/X.npy (windows of raw IMU samples) and data/y.npy (labels).

Dataset:
  Roggen et al., "Collecting complex activity datasets in highly rich networked
  sensor environments," INSS 2010.
  https://archive.ics.uci.edu/dataset/226/opportunity+activity+recognition

Run:
  python prepare_data.py
"""

import io
import zipfile
import urllib.request
from pathlib import Path

import numpy as np
import pandas as pd

# ── Config ────────────────────────────────────────────────────────────────────

DATASET_URL = (
    "https://archive.ics.uci.edu/ml/machine-learning-databases"
    "/00226/OpportunityUCIDataset.zip"
)
DATA_DIR = Path("data")

# 1-second window at 50 Hz (matches Apple Watch CMMotionManager rate)
WINDOW_SIZE = 50
STRIDE = 25          # 50% overlap

# OPPORTUNITY gesture label for "Drink from Cup"
# Verified against OpportunityUCIDataset/dataset/label_legend.txt
DRINK_LABEL = 406519

# Right Lower Arm (RLA) IMU — closest analogue to Apple Watch position.
# Column indices are 1-based in the raw .dat files (column 0 is timestamp ms).
# Accel X/Y/Z: cols 64–66, Gyro X/Y/Z: cols 73–75
# Verify with: load_column_names() below
RLA_ACCEL_COLS = [64, 65, 66]
RLA_GYRO_COLS  = [73, 74, 75]
SENSOR_COLS    = RLA_ACCEL_COLS + RLA_GYRO_COLS

# Gesture label column (0-based index in the .dat file)
GESTURE_COL = 243

# ADL (Activities of Daily Living) files — contain the "Drink from Cup" gesture
ADL_GLOB = "S*-ADL*.dat"

# ── Helpers ───────────────────────────────────────────────────────────────────

def load_column_names(dataset_dir: Path) -> list[str]:
    """Return the list of column names from the dataset's label legend."""
    names_file = dataset_dir / "dataset" / "column_names.txt"
    if names_file.exists():
        return names_file.read_text().splitlines()
    return []


def verify_sensor_cols(dataset_dir: Path) -> None:
    """Print the column names at SENSOR_COLS so you can verify they are RLA IMU."""
    names = load_column_names(dataset_dir)
    if not names:
        print("column_names.txt not found — skipping column verification.")
        return
    print("Sensor column verification:")
    for i in SENSOR_COLS:
        label = names[i] if i < len(names) else "?"
        print(f"  col {i}: {label}")


# ── Download ──────────────────────────────────────────────────────────────────

def download(dataset_dir: Path) -> None:
    if (dataset_dir / "dataset").exists():
        print("Dataset already extracted.")
        return
    zip_path = DATA_DIR / "opportunity.zip"
    if not zip_path.exists():
        print(f"Downloading OPPORTUNITY dataset (~130 MB) from {DATASET_URL} ...")
        urllib.request.urlretrieve(DATASET_URL, zip_path)
        print("Download complete.")
    print("Extracting...")
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(dataset_dir.parent)
    print("Extracted.")


# ── Windowing ─────────────────────────────────────────────────────────────────

def make_windows(df: pd.DataFrame):
    data = df.values
    X, y = [], []
    for start in range(0, len(data) - WINDOW_SIZE, STRIDE):
        window = data[start : start + WINDOW_SIZE]

        features = window[:, SENSOR_COLS].astype(float)
        if np.isnan(features).any():
            continue  # skip windows with missing sensor data

        gesture_vals = window[:, GESTURE_COL]
        valid = gesture_vals[~np.isnan(gesture_vals)]
        if len(valid) == 0:
            label = "other"
        else:
            unique, counts = np.unique(valid, return_counts=True)
            majority = unique[counts.argmax()]
            label = "drink" if majority == DRINK_LABEL else "other"

        X.append(features.flatten())
        y.append(label)

    return np.array(X, dtype=np.float32), np.array(y)


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    DATA_DIR.mkdir(exist_ok=True)
    dataset_dir = DATA_DIR / "OpportunityUCIDataset"

    download(dataset_dir)
    verify_sensor_cols(dataset_dir)

    dat_files = sorted((dataset_dir / "dataset").glob(ADL_GLOB))
    if not dat_files:
        raise FileNotFoundError(
            f"No .dat files matching {ADL_GLOB} found in {dataset_dir / 'dataset'}. "
            "Check the extraction path."
        )

    all_X, all_y = [], []
    for path in dat_files:
        print(f"  Processing {path.name} ...")
        df = pd.read_csv(path, sep=" ", header=None)
        X, y = make_windows(df)
        all_X.append(X)
        all_y.append(y)

    X = np.vstack(all_X)
    y = np.concatenate(all_y)

    drink_n = (y == "drink").sum()
    other_n = (y == "other").sum()
    print(f"\nWindows — drink: {drink_n}, other: {other_n} "
          f"(imbalance ratio 1:{other_n // max(drink_n, 1)})")

    np.save(DATA_DIR / "X.npy", X)
    np.save(DATA_DIR / "y.npy", y)
    print(f"Saved {DATA_DIR}/X.npy and {DATA_DIR}/y.npy")
    print(f"Window shape: {X.shape}  (n_windows, {WINDOW_SIZE} steps × {len(SENSOR_COLS)} channels flattened)")


if __name__ == "__main__":
    main()
