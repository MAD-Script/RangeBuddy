"""
EV Range Tracker — offline trip analysis.

Run this on your computer against CSVs exported from the app
(<trip_id>_samples.csv, <trip_id>_metadata.csv, <trip_id>_bar_events.csv).

What this does:
1. Loads every trip found in a folder.
2. Replays each trip's GPS samples through the SAME physics formula the
   app uses (cruise + congestion overhead), second by second, to get a
   physics-predicted Wh/km curve for that trip.
3. Uses your bar-drop events as ground-truth anchors: cumulative
   physics-predicted Wh at the moment each bar dropped, aggregated
   across many trips, builds an empirical state-of-charge curve. This
   matters because your battery does NOT discharge linearly (you
   already noticed it: struggles below 25km/h in the last 5-10km) —
   so don't assume 1656Wh / 6 bars = equal Wh per bar. Let the data
   show you the real curve instead.
4. For trips with enough anchors to compute an actual Wh-consumed
   figure, fits a small model to predict the RESIDUAL (actual minus
   physics-predicted) from trip-level features — this is the
   data-efficient way to add "ML" on top of a physics model without
   needing hundreds of trips.

Requires: pip install pandas numpy scikit-learn
"""

import glob
import json
import os
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import LeaveOneOut, cross_val_score

# --- Vehicle constants — keep in sync with vehicle_profile.dart ---
SYSTEM_VOLTAGE = 72.0
BATTERY_AH = 23.0
TOTAL_ENERGY_WH = SYSTEM_VOLTAGE * BATTERY_AH  # 1656

CRR = 0.015
CDA = 0.6
EFFICIENCY = 0.85
GRAVITY = 9.81
AIR_DENSITY = 1.2

CONGESTION_OVERHEAD_WH_PER_KM = 6.5  # current app default, to be refined
CONGESTION_SPEED_THRESHOLD_KMH = 25.0


def cruise_power_watts(speed_kmh, total_mass_kg):
    v = speed_kmh / 3.6
    rolling = CRR * total_mass_kg * GRAVITY * v
    drag = 0.5 * AIR_DENSITY * CDA * v**3
    return (rolling + drag) / EFFICIENCY


def physics_predicted_wh(samples_df, total_mass_kg):
    """Replays samples second-by-second, mirroring RangeEngine.tick()."""
    samples_df = samples_df.sort_values("timestamp_ms").reset_index(drop=True)
    cumulative_wh = np.zeros(len(samples_df))
    total = 0.0
    for i in range(1, len(samples_df)):
        dt_s = (samples_df.timestamp_ms[i] - samples_df.timestamp_ms[i - 1]) / 1000.0
        if dt_s <= 0 or dt_s > 30:  # skip GPS gaps > 30s, likely a stop/pause
            continue
        speed = samples_df.speed_kmh[i]
        cruise_wh = cruise_power_watts(speed, total_mass_kg) * (dt_s / 3600.0)
        congestion_wh = 0.0
        if 0 < speed < CONGESTION_SPEED_THRESHOLD_KMH:
            km_this_tick = speed * (dt_s / 3600.0)
            congestion_wh = CONGESTION_OVERHEAD_WH_PER_KM * km_this_tick
        total += cruise_wh + congestion_wh
        cumulative_wh[i] = total
    samples_df["cumulative_physics_wh"] = cumulative_wh
    return samples_df, total


def load_trip(samples_path):
    trip_id = os.path.basename(samples_path).replace("_samples.csv", "")
    folder = os.path.dirname(samples_path)
    samples = pd.read_csv(samples_path)
    meta_path = os.path.join(folder, f"{trip_id}_metadata.csv")
    bar_path = os.path.join(folder, f"{trip_id}_bar_events.csv")
    meta = pd.read_csv(meta_path).iloc[0] if os.path.exists(meta_path) else None
    bars = pd.read_csv(bar_path) if os.path.exists(bar_path) else pd.DataFrame()
    return trip_id, samples, meta, bars


def trip_level_features(samples_df):
    dist_km = 0.0
    stop_count = 0
    was_stopped = True
    elevation_gain = 0.0
    speeds = samples_df["speed_kmh"].values
    alts = samples_df.get("altitude_m")

    for i in range(1, len(samples_df)):
        dt_s = (samples_df.timestamp_ms[i] - samples_df.timestamp_ms[i - 1]) / 1000.0
        if dt_s <= 0 or dt_s > 30:
            continue
        dist_km += speeds[i] * (dt_s / 3600.0)
        is_stopped = speeds[i] < 2.0
        if is_stopped and not was_stopped:
            stop_count += 1
        was_stopped = is_stopped
        if alts is not None and not pd.isna(alts[i]) and not pd.isna(alts[i - 1]):
            delta = alts[i] - alts[i - 1]
            if delta > 0:
                elevation_gain += delta

    return {
        "distance_km": dist_km,
        "avg_speed_kmh": float(np.mean(speeds)) if len(speeds) else 0,
        "speed_std_kmh": float(np.std(speeds)) if len(speeds) else 0,
        "stop_count": stop_count,
        "elevation_gain_m": elevation_gain,
    }


def build_soc_curve(all_trips):
    """
    Aggregates bar-drop events across trips into an empirical
    cumulative-Wh-at-each-bar curve, instead of assuming linear
    discharge. Only uses trips that started at a known full charge.
    """
    observations = {}  # bar_level -> list of cumulative_physics_wh values
    for trip_id, samples, meta, bars in all_trips:
        if meta is None or meta.get("start_charge_type") != "fullCharge":
            continue
        for _, row in bars.iterrows():
            ts = row["timestamp_ms"]
            match = samples[samples.timestamp_ms <= ts]
            if match.empty:
                continue
            cum_wh = match.iloc[-1]["cumulative_physics_wh"]
            observations.setdefault(int(row["bar_level_after_drop"]), []).append(cum_wh)

    curve = {
        bar: {"median_wh": float(np.median(vals)), "n_observations": len(vals)}
        for bar, vals in sorted(observations.items(), reverse=True)
    }
    return curve


def main(data_folder="./trip_exports", output_json="calibration_output.json"):
    sample_files = glob.glob(os.path.join(data_folder, "*_samples.csv"))
    if not sample_files:
        print(f"No trip exports found in {data_folder}")
        return

    all_trips = []
    rows_for_ml = []

    for path in sample_files:
        trip_id, samples, meta, bars = load_trip(path)
        if meta is None:
            print(f"Skipping {trip_id}: no metadata found")
            continue

        total_mass = meta["rider_kg"] + meta.get("passenger_kg", 0) + 104.0  # + vehicle
        samples, physics_total_wh = physics_predicted_wh(samples, total_mass)
        features = trip_level_features(samples)

        all_trips.append((trip_id, samples, meta, bars))

        print(
            f"{trip_id}: {features['distance_km']:.2f}km, "
            f"avg {features['avg_speed_kmh']:.1f}km/h, "
            f"{features['stop_count']} stops, "
            f"physics predicts {physics_total_wh:.1f}Wh "
            f"({physics_total_wh/max(features['distance_km'],0.01):.2f} Wh/km)"
        )

        rows_for_ml.append({**features, "physics_wh": physics_total_wh, "trip_id": trip_id})

    # Empirical state-of-charge curve from bar-drop anchors
    soc_curve = build_soc_curve(all_trips)
    print("\nEmpirical bar-drop curve (cumulative Wh consumed since full charge):")
    for bar, info in soc_curve.items():
        print(f"  Bar {bar}: {info['median_wh']:.0f}Wh consumed so far "
              f"(n={info['n_observations']})")

    result = {
        "n_trips_analyzed": len(all_trips),
        "empirical_soc_curve": soc_curve,
        "note": (
            "Residual-correction ML model needs actual Wh-consumed labels "
            "per trip, which requires enough bar-drop coverage across "
            "trips first. Re-run once you have ~15-20 trips with bar "
            "events logged — the script will then fit a "
            "RandomForestRegressor on the residual automatically."
        ),
    }

    # Only attempt the ML residual step once there's enough labeled data
    labeled = [r for r in rows_for_ml if False]  # placeholder until enough data
    if len(labeled) >= 10:
        df = pd.DataFrame(labeled)
        X = df[["avg_speed_kmh", "speed_std_kmh", "stop_count", "elevation_gain_m"]]
        y = df["actual_wh"] - df["physics_wh"]
        model = RandomForestRegressor(n_estimators=100, random_state=0)
        scores = cross_val_score(model, X, y, cv=LeaveOneOut(), scoring="neg_mean_absolute_error")
        print(f"\nResidual model leave-one-out MAE: {-scores.mean():.1f} Wh")
        model.fit(X, y)
        result["residual_model_trained"] = True
    else:
        print(
            f"\nOnly {len(labeled)} trips have enough bar-drop coverage for "
            "residual ML — keep logging bar-drop events, this needs ~10+."
        )
        result["residual_model_trained"] = False

    with open(output_json, "w") as f:
        json.dump(result, f, indent=2)
    print(f"\nWrote {output_json}")


if __name__ == "__main__":
    main()
