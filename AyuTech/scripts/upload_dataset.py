import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd

# Load Firebase service account key
cred = credentials.Certificate("serviceAccountKey.json")  # make sure this JSON is in the same folder
firebase_admin.initialize_app(cred)

db = firestore.client()

# Load dataset (CSV is in the same folder as this script)
df = pd.read_csv("dataset.csv")

# Replace NaN with None
df = df.where(pd.notnull(df), None)

# Upload in batches
batch_size = 500
docs = df.to_dict(orient="records")

for i in range(0, len(docs), batch_size):
    batch = db.batch()
    chunk = docs[i:i+batch_size]

    for row in chunk:
        doc_ref = db.collection("dietPlans").document()
        batch.set(doc_ref, row)

    batch.commit()
    print(f"✅ Uploaded {i+len(chunk)} / {len(docs)} rows")

print("🎉 All rows uploaded successfully!")
