# server_feature_builder.py
import numpy as np

# -----------------------------
# Helper encoders
# -----------------------------

def severity_to_num(s):
    if not s:
        return 0.0
    s = str(s).strip().lower()
    mapping = {
        "none": 0.0,
        "mild": 1.0,
        "moderate": 2.0,
        "severe": 3.0
    }
    return mapping.get(s, 0.0)


def water_to_num(wstr):
    """Convert '1-2L/day' or '1–2L' or '2L' → numeric average."""
    if not wstr:
        return 1.5
    s = str(wstr).lower()
    s = s.replace("l", "").replace("–", "-").replace(" ", "")
    if "-" in s:
        parts = s.split("-")
        try:
            nums = [float(p) for p in parts if p]
            return sum(nums) / len(nums)
        except:
            return 1.5
    try:
        return float(s)
    except:
        return 1.5


def diet_to_num(d):
    """Simple mapping: veg / nonveg / vegan / etc → numeric or one-hot later."""
    if not d:
        return 0.0
    d = d.strip().lower()
    mapping = {
        "veg": 1.0,
        "vegetarian": 1.0,
        "nonveg": 2.0,
        "non-veg": 2.0,
        "vegan": 3.0
    }
    return mapping.get(d, 0.0)


def region_to_num(r):
    """Map region to numeric."""
    if not r:
        return 0.0
    r = r.strip().lower()
    mapping = {
        "north": 1.0,
        "south": 2.0,
        "east": 3.0,
        "west": 4.0,
        "central": 5.0
    }
    return mapping.get(r, 0.0)


def bowel_to_num(b):
    if not b:
        return 1.0
    b = b.strip().lower()
    mapping = {
        "regular": 1.0,
        "constipated": 0.0,
        "loose": 2.0
    }
    return mapping.get(b, 1.0)


# ---------------------------------------------
# MAIN FUNCTION – BUILD FINAL NUMERIC FEATURES
# ---------------------------------------------

def build_feature_vector_from_columns(raw: dict, model_input_len: int):
    """
    raw = dictionary from Flutter UI
    model_input_len = input length from TFLite model (ex: 100)

    Returns a numpy float32 array shaped (1, model_input_len)
    """

    features = []

    # -----------------------------
    # 1. BASIC PATIENT METADATA
    # -----------------------------
    age = float(raw.get("age", 30))
    features.append(age)

    gender_raw = str(raw.get("gender", "male")).lower()
    gender_num = 1.0 if gender_raw in ("male", "m") else 0.0
    features.append(gender_num)

    region_num = region_to_num(raw.get("region"))
    features.append(region_num)

    # -----------------------------
    # 2. SYMPTOMS & SEVERITY
    # -----------------------------
    severity = severity_to_num(raw.get("symptom_severity"))
    features.append(severity)

    bowel = bowel_to_num(raw.get("bowel_movement"))
    features.append(bowel)

    # -----------------------------
    # 3. LIFESTYLE
    # -----------------------------
    # Sleep hours
    sleep_raw = raw.get("sleep_h")
    try:
        sleep_h = float(sleep_raw)
    except:
        sleep_h = 7.0
    features.append(sleep_h)

    # Water intake
    water = water_to_num(raw.get("water_intake"))
    features.append(water)

    # Diet
    diet = diet_to_num(raw.get("diet"))
    features.append(diet)

    # Physical activity (optional)
    pa = raw.get("physical_activity", "").lower()
    mapping_pa = {
        "sedentary": 0.0,
        "light activity": 1.0,
        "moderate activity": 2.0,
        "high activity": 3.0
    }
    features.append(mapping_pa.get(pa, 1.0))

    # -----------------------------
    # 4. ANTHROPOMETRY
    # -----------------------------
    height = raw.get("height_cm")
    weight = raw.get("weight_kg")

    try:
        height_f = float(height)
    except:
        height_f = 0.0

    try:
        weight_f = float(weight)
    except:
        weight_f = 0.0

    if height_f > 0:
        bmi = weight_f / ((height_f / 100) ** 2)
    else:
        bmi = 22.0

    features.append(height_f)
    features.append(weight_f)
    features.append(bmi)

    # -----------------------------
    # (UP TO HERE ARE YOUR UI FIELDS)
    # -----------------------------

    # -----------------------------------------
    # 5. PAD REMAINING FIELDS WITH ZEROES
    # -----------------------------------------
    # If model_input_len is 100, and we filled 14 values,
    # fill remaining 86 with zeros.
    if len(features) < model_input_len:
        padding_len = model_input_len - len(features)
        features += [0.0] * padding_len

    elif len(features) > model_input_len:
        features = features[:model_input_len]

    # Final numpy conversion
    arr = np.array(features, dtype=np.float32).reshape(1, -1)
    return arr
