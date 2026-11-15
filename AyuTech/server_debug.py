# server_debug.py  — paste this entire file into your server_debug.py and save
import os, traceback
import numpy as np
import tensorflow as tf
from flask import Flask

print("\n=== DEBUG SERVER STARTING ===", flush=True)

app = Flask(__name__)

MODEL_DIR = os.path.join(os.getcwd(), "assets", "models")
MODEL_FILES = {
    "prakriti": "mlp_prakriti_predictor.tflite",
    "dosha": "dnn_dosha_imbalance_predictor.tflite",
    "nutrient": "nutrient_new.tflite",
    "meal_ranker": "meal_ranker.tflite",
}

interpreters = {}

def load_interpreter(path):
    print(f"[LOAD] Loading model: {path}", flush=True)
    interp = tf.lite.Interpreter(model_path=path)
    interp.allocate_tensors()
    print("[LOAD] OK", flush=True)
    return interp

def load_models():
    print(f"[DEBUG] Scanning model directory: {MODEL_DIR}", flush=True)
    for key, filename in MODEL_FILES.items():
        full_path = os.path.join(MODEL_DIR, filename)
        if not os.path.exists(full_path):
            print(f"[ERROR] Not found: {full_path}", flush=True)
            continue
        try:
            interpreters[key] = load_interpreter(full_path)
            ids = interpreters[key].get_input_details()
            ods = interpreters[key].get_output_details()
            print(f"  {key}: inputs={ [d['shape'].tolist() for d in ids] } outputs={ [d['shape'].tolist() for d in ods] }", flush=True)
        except Exception as e:
            print(f"[FAIL] Could not load {filename}: {e}", flush=True)
            traceback.print_exc()

@app.route("/ping")
def ping():
    return "PING OK"

if __name__ == "__main__":
    print(">>> LOADING MODELS...", flush=True)
    load_models()
    print(">>> STARTING FLASK ON 127.0.0.1:5000", flush=True)
    app.run(host="127.0.0.1", port=5000)
