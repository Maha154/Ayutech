# server.py
from flask import Flask, request, jsonify
import numpy as np
import tensorflow as tf
import threading
import traceback
import os

app = Flask(__name__)

# Load all models once on server start:
MODEL_DIR = os.path.join(os.getcwd(), "assets", "models")  # adjust if needed

# Map logical names to filenames
MODEL_FILES = {
    "prakriti": "mlp_prakriti_predictor.tflite",
    "dosha": "dnn_dosha_imbalance_predictor.tflite",
    "nutrient": "nutrient_new.tflite",
    "meal_ranker": "meal_ranker.tflite",
}

interpreters = {}

def load_interpreter(path):
    interpreter = tf.lite.Interpreter(model_path=path)
    interpreter.allocate_tensors()
    return interpreter

def load_models():
    for key, filename in MODEL_FILES.items():
        full = os.path.join(MODEL_DIR, filename)
        if not os.path.exists(full):
            print(f"[WARN] Model file not found: {full}")
            continue
        print(f"[INFO] Loading {key} -> {full}")
        try:
            interpreters[key] = load_interpreter(full)
            input_details = interpreters[key].get_input_details()
            output_details = interpreters[key].get_output_details()
            print(f"  input_shapes: {[d['shape'].tolist() for d in input_details]}")
            print(f"  output_shapes: {[d['shape'].tolist() for d in output_details]}")
        except Exception as e:
            print(f"[ERROR] Failed to load {full}: {e}")
            traceback.print_exc()

def run_tflite(interpreter, input_list):
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    in_shape = input_details[0]["shape"]
    in_dtype = input_details[0]["dtype"]
    arr = np.asarray(input_list, dtype=in_dtype)
    try:
        target_shape = tuple(in_shape)
        if len(target_shape) == 2 and target_shape[0] == 1:
            arr = arr.reshape((1, target_shape[1]))
        elif len(target_shape) == 1:
            arr = arr.reshape(target_shape)
        else:
            arr = arr.reshape(target_shape)
    except Exception:
        arr = np.expand_dims(arr, axis=0)

    interpreter.set_tensor(input_details[0]['index'], arr)
    interpreter.invoke()

    outputs = []
    for od in output_details:
        out = interpreter.get_tensor(od['index'])
        outputs.append(out.tolist())
    return outputs

# make sure this import exists near the top of server.py
from server_feature_builder import build_feature_vector_from_columns

@app.route("/predict/<model_name>", methods=["POST"])
def predict(model_name):
    try:
        if model_name not in interpreters:
            return jsonify({"success": False, "error": f"Model {model_name} not loaded."}), 400

        payload = request.get_json(force=True) or {}

        # If client already provided a numeric input vector under "input", use it.
        if isinstance(payload.get("input"), (list, tuple)):
            input_arr = payload["input"]
        else:
            # Otherwise build a numeric feature vector from raw fields using the builder.
            interp = interpreters[model_name]
            input_details = interp.get_input_details()
            expected_shape = input_details[0]["shape"]
            expected_len = int(expected_shape[1]) if len(expected_shape) > 1 else int(np.prod(expected_shape))

            # Build the vector (this returns a numpy array shaped (1, expected_len))
            input_arr_np = build_feature_vector_from_columns(payload, model_input_len=expected_len)

            # DEBUG (temporary): print shape + first 20 values to verify ordering
            print(f"[DEBUG] model={model_name} feature_vector_shape={input_arr_np.shape} preview={input_arr_np.tolist()[0][:20]}")

            # Convert to list for run_tflite
            input_arr = input_arr_np.tolist()[0]

        outputs = run_tflite(interpreters[model_name], input_arr)
        return jsonify({"success": True, "outputs": outputs})

    except Exception as e:
        tb = traceback.format_exc()
        print("Prediction error:", tb)
        return jsonify({"success": False, "error": str(e), "trace": tb}), 500

