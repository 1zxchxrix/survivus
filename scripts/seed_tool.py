#!/usr/bin/env python3
import base64, datetime as dt, json, os
from pathlib import Path
import typing as t

CREDENTIALS_PATH = "/Users/zachariasalad/Desktop/firestore-tools/service-account.json"
PROJECT_ID = "survivus1514"
SNAPSHOTS_ROOT = "/Users/zachariasalad/Desktop/firestore-tools/snapshots"
DEFAULT_BUCKET = f"{PROJECT_ID}.firebasestorage.app"
DEFAULT_PREFIXES = ["users/", "contestants/"]

import firebase_admin
from firebase_admin import credentials, firestore

try:
    from google.cloud import storage as gcs
    HAS_GCS = True
except Exception:
    HAS_GCS = False

def _parse_timestamp(iso: str) -> dt.datetime:
    if iso.endswith("Z"):
        iso2 = iso[:-1]; return dt.datetime.fromisoformat(iso2).replace(tzinfo=dt.timezone.utc)
    return dt.datetime.fromisoformat(iso)

def _deserialize_value(v, db):
    if isinstance(v, dict) and "_type" in v:
        tname = v.get("_type")
        if tname == "timestamp": return _parse_timestamp(v["iso"])
        if tname == "bytes": return base64.b64decode(v["base64"])
        if tname == "docref": return db.document(v["path"])
        if tname == "geopoint":
            try:
                from google.cloud.firestore_v1 import GeoPoint
            except Exception:
                class GeoPoint:
                    def __init__(self, latitude, longitude): self.latitude = latitude; self.longitude = longitude
            return GeoPoint(v["lat"], v["lon"])
        return v
    if isinstance(v, list): return [_deserialize_value(x, db) for x in v]
    if isinstance(v, dict): return {k: _deserialize_value(x, db) for k, x in v.items()}
    return v

def _delete_collection_recursive(db, col_ref, batch_size=500):
    docs = list(col_ref.limit(batch_size).stream())
    while docs:
        batch = db.batch()
        for d in docs:
            for sub in d.reference.collections(): _delete_collection_recursive(db, sub, batch_size)
            batch.delete(d.reference)
        batch.commit()
        docs = list(col_ref.limit(batch_size).stream())

def _restore_doc(db, entry: dict):
    ref = db.document(entry["_path"])
    fields = _deserialize_value(entry.get("fields", {}), db)
    ref.set(fields)
    for sub in entry.get("_subcollections", []) or []: _restore_collection(db, sub)

def _restore_collection(db, col_dump: dict):
    for doc_entry in col_dump.get("documents", []) or []: _restore_doc(db, doc_entry)

def prefix_dir_name(prefix: str) -> str:
    p = prefix.strip("/")
    if p == "users": return "users_avatars"
    if p == "contestants": return "contestants_avatars"
    return p if p else "root"

def compute_metrics_from_snapshot(snap: dict) -> dict:
    fs = snap.get("firestore") or {}
    def _walk(col_dump):
        for d in col_dump.get("documents", []) or []:
            yield d
            for sub in d.get("_subcollections", []) or []:
                for x in _walk(sub): yield x
    results = season_picks = weekly_picks = 0
    for col in fs.get("rootCollections", []):
        for d in _walk(col):
            p = d.get("_path", "")
            if "/results/" in p: results += 1
            if "/seasonPicks/" in p: season_picks += 1
            if "/weeklyPicks/" in p and "/episodes/" in p: weekly_picks += 1
    return {"results": results, "seasonPicks": season_picks, "weeklyPicks": weekly_picks}

def _clear_bucket_prefixes(client, bucket, prefixes: t.List[str]) -> dict:
    report = {"cleared": {}, "errors": []}
    for pfx in prefixes:
        deleted = 0
        try:
            for blob in client.list_blobs(bucket.name, prefix=pfx):
                try:
                    blob.delete(); deleted += 1
                except Exception as e:
                    report["errors"].append({"name": blob.name, "error": str(e)})
            report["cleared"][pfx] = deleted
        except Exception as e:
            report["errors"].append({"prefix": pfx, "error": str(e)})
    return report

def _print_snapshot_summary(snap_dir: Path):
    summary = snap_dir / "snapshot_summary.md"
    if summary.exists():
        print("\n--- Snapshot Summary ---")
        print(summary.read_text(encoding="utf-8"))
        print("------------------------\n")

def seed_from_snapshot_folder(credentials_path: str, project_id: str, snapshot_folder: Path, only_seasons: bool, wipe_before: bool=True, seed_storage: bool=False, clear_storage_prefixes: bool=False):
    cred = credentials.Certificate(credentials_path)
    if not firebase_admin._apps: firebase_admin.initialize_app(cred, {"projectId": project_id} if project_id else None)
    db = firestore.client()

    _print_snapshot_summary(snapshot_folder)

    snap = json.loads((snapshot_folder / "snapshot.json").read_text(encoding="utf-8"))
    metrics = snap.get("metrics") or compute_metrics_from_snapshot(snap)
    if metrics.get("results", 0) > 0 and metrics.get("weeklyPicks", 0) == 0:
        print("WARNING: Snapshot contains results but no weekly picks; VO/IM/RM scoring cannot be rebuilt from this snapshot.")
        if not input("Proceed with seeding anyway? [y/N]: ").strip().lower().startswith("y"): return

    fs = snap.get("firestore") or {}
    roots = fs.get("rootCollections", [])

    target_col_names = set()
    for col in roots:
        name = col.get("_collection", "").split("/")[0]
        if only_seasons and name != "seasons": continue
        target_col_names.add(name)

    if wipe_before:
        for col_name in target_col_names:
            print(f"Deleting collection: {col_name} ..."); _delete_collection_recursive(db, db.collection(col_name))

    for col in roots:
        name = col.get("_collection", "").split("/")[0]
        if only_seasons and name != "seasons": continue
        _restore_collection(db, col)

    print(f"Seeded Firestore collections: {sorted(target_col_names)}")

    if seed_storage and HAS_GCS:
        client = gcs.Client.from_service_account_json(credentials_path); bucket = client.bucket(DEFAULT_BUCKET)
        if clear_storage_prefixes:
            print("Clearing bucket prefixes before upload...")
            clear_report = _clear_bucket_prefixes(client, bucket, DEFAULT_PREFIXES)
            for pfx, n in clear_report.get("cleared", {}).items(): print(f"  Cleared {n} objects under prefix '{pfx}'")
            if clear_report.get("errors"): print(f"  Errors while clearing ({len(clear_report['errors'])})")
        uploaded = 0
        for pfx in DEFAULT_PREFIXES:
            folder = snapshot_folder / prefix_dir_name(pfx)
            if not folder.exists(): continue
            for fname in os.listdir(folder):
                src = folder / fname
                if not src.is_file(): continue
            blob_name = f"{pfx}{fname}"; bucket.blob(blob_name).upload_from_filename(str(src)); uploaded += 1
        print(f"Uploaded {uploaded} Storage files to {bucket.name}")

    elif seed_storage and not HAS_GCS:
        print("google-cloud-storage not installed; skipping Storage upload.")

def main():
    base_dir = Path(SNAPSHOTS_ROOT); base_dir.mkdir(parents=True, exist_ok=True)
    dirs = [d for d in sorted(base_dir.iterdir()) if d.is_dir() and d.name.startswith("snapshot_")]
    if not dirs:
        print("No snapshot folders found. Create one with the snapshot tool first."); return

    print("\\n=== Seed Tool ===")
    print("Available snapshots:")
    for i, d in enumerate(dirs, 1): print(f"  {i}) {d.name}")
    idx = input("Select snapshot number: ").strip()
    try:
        idxi = int(idx) - 1; chosen = dirs[idxi]
    except Exception:
        print("Invalid selection."); return

    only = input("Seed only 'seasons' collection? [y/N]: ").strip().lower().startswith('y')
    both = input("Also seed Storage files (upload) if present? [y/N]: ").strip().lower().startswith('y')
    clear = False
    if both: clear = input("Clear bucket prefixes ('users/', 'contestants/') before upload? [y/N]: ").strip().lower().startswith('y')

    print("\\n*** DANGER ZONE *** This will DELETE targeted Firestore collections before seeding.")
    if input("Type 'DELETE' to confirm: ").strip() != "DELETE": print("Aborted."); return

    seed_from_snapshot_folder(CREDENTIALS_PATH, PROJECT_ID, chosen, only_seasons=only, wipe_before=True, seed_storage=both, clear_storage_prefixes=clear)
    print(f"\\nSeeding complete from {chosen}\\n")

if __name__ == "__main__":
    main()
