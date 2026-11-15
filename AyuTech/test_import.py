import traceback, importlib
try:
    importlib.import_module("server")
    print("IMPORT OK")
except Exception:
    traceback.print_exc()
