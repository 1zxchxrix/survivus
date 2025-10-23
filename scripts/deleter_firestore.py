import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("path/to/service-account.json")
firebase_admin.initialize_app(cred)

client = firestore.client()
season_id = "season-001"

def delete_collection(collection_ref):
    for doc in collection_ref.stream():
        # Recursively delete subcollections
        for subcollection in doc.collections():
            delete_collection(subcollection)
        doc.reference.delete()

collections = ["state", "phases", "results", "seasonPicks", "weeklyPicks"]
for name in collections:
    print(f"Deleting {name} for {season_id}")
    col_ref = client.collection("seasons").document(season_id).collection(name)
    delete_collection(col_ref)

print("Deletion complete.")
