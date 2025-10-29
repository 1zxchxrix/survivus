#!/usr/bin/env python3
import base64, datetime as dt, json, typing as t
from pathlib import Path

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

def _serialize_value(v):
    try:
        from google.cloud.firestore import DocumentReference
    except Exception:
        class DocumentReference: pass
    import datetime as _dt
    if isinstance(v, _dt.datetime):
        if v.tzinfo is not None:
            v = v.astimezone(_dt.timezone.utc).replace(tzinfo=None)
        return {"_type": "timestamp", "iso": v.isoformat(timespec="microseconds") + "Z"}
    if isinstance(v, bytes):
        return {"_type": "bytes", "base64": base64.b64encode(v).decode("ascii")}
    if 'DocumentReference' in globals() and isinstance(v, DocumentReference):
        return {"_type": "docref", "path": v.path}
    if hasattr(v, "latitude") and hasattr(v, "longitude"):
        try:
            return {"_type": "geopoint", "lat": float(v.latitude), "lon": float(v.longitude)}
        except Exception:
            pass
    if isinstance(v, (list, tuple)):
        return [_serialize_value(x) for x in v]
    if isinstance(v, dict):
        return {k: _serialize_value(val) for k, val in v.items()}
    return v

def _index_collections_by_path(fs_dump: dict) -> dict:
    """Map _collection path -> collection dict object in the dump."""
    idx = {}
    def walk(col):
        idx[col["_collection"]] = col
        for d in col.get("documents", []):
            for sub in d.get("_subcollections", []) or []:
                walk(sub)
    for rc in fs_dump.get("rootCollections", []):
        walk(rc)
    return idx

def _find_doc_entry(fs_dump: dict, doc_path: str) -> t.Optional[dict]:
    """Return the doc dict in the dump by exact _path, if present."""
    def walk_docs(col):
        for d in col.get("documents", []):
            if d.get("_path") == doc_path:
                return d
            for sub in d.get("_subcollections", []) or []:
                got = walk_docs(sub)
                if got: return got
        return None
    for rc in fs_dump.get("rootCollections", []):
        got = walk_docs(rc)
        if got: return got
    return None

def _ensure_subcollection(doc_entry: dict, collection_path: str) -> dict:
    """Ensure doc_entry has a subcollection object with this path; create if missing."""
    subs = doc_entry.setdefault("_subcollections", [])
    for c in subs:
        if c.get("_collection") == collection_path:
            return c
    c = {"_collection": collection_path, "documents": []}
    subs.append(c)
    return c

def _ensure_missing_parent_doc(fs_dump: dict, parent_doc_path: str) -> dict:
    """Make a synthetic empty doc in the dump (so episodes can hang under it)."""
    existing = _find_doc_entry(fs_dump, parent_doc_path)
    if existing:
        return existing
    # parent_doc_path like: seasons/season-001/weeklyPicks/u1
    parent_col_path = "/".join(parent_doc_path.split("/")[:-1])
    parent_doc_id   = parent_doc_path.split("/")[-1]
    # find the doc that owns the parent collection (e.g., seasons/season-001)
    owner_doc_path  = "/".join(parent_col_path.split("/")[:-1])
    owner_doc       = _find_doc_entry(fs_dump, owner_doc_path)
    if not owner_doc:
        # if we can't find the owner (unexpected), bail and rely on existing traversal
        return None
    # attach the parent collection to the owner
    parent_col = _ensure_subcollection(owner_doc, parent_col_path)
    # create the synthetic parent doc
    synth = {
        "_id": parent_doc_id,
        "_path": parent_doc_path,
        "_createTime": None,
        "_updateTime": None,
        "fields": {}
    }
    parent_col["documents"].append(synth)
    return synth

def _serialize_episode_doc(doc) -> dict:
    def _safe_iso(val):
        try:
            if hasattr(val, "isoformat"):
                return val.isoformat()
        except Exception:
            pass
        return None

    return {
        "_id": doc.id,
        "_path": doc.reference.path,
        "_createTime": _safe_iso(getattr(doc, "create_time", None)),
        "_updateTime": _safe_iso(getattr(doc, "update_time", None)),
        "fields": _serialize_value(doc.to_dict() or {}),
    }

def augment_with_weekly_picks_via_collection_group(db, fs_dump: dict) -> int:
    """
    Find seasons/*/weeklyPicks/*/episodes/* using a collection group query,
    and insert them into the dump even if weeklyPicks/<userId> parent docs are 'missing'.
    Returns number of episode docs added.
    """
    added = 0
    try:
        cg = db.collection_group("episodes").stream()
    except Exception:
        # SDK older than collection group, or other error
        return 0

    for ep in cg:
        # Expect path: seasons/<sid>/weeklyPicks/<uid>/episodes/<eid>
        parts = ep.reference.path.split("/")
        if len(parts) < 6 or parts[-2] != "episodes" or "weeklyPicks" not in parts:
            continue
        parent_doc_path = "/".join(parts[:-2])  # .../weeklyPicks/<uid>
        episodes_col_path = parent_doc_path + "/episodes"

        parent_doc_entry = _ensure_missing_parent_doc(fs_dump, parent_doc_path)
        if not parent_doc_entry:
            continue
        episodes_col = _ensure_subcollection(parent_doc_entry, episodes_col_path)

        episodes_col["documents"].append(_serialize_episode_doc(ep))
        added += 1
    return added


def _doc_to_serializable(doc) -> dict:
    data = doc.to_dict() or {}
    converted = {k: _serialize_value(v) for k, v in data.items()}
    return {"_id": doc.id, "_path": doc.reference.path, "_createTime": getattr(doc, "create_time", None).isoformat() if getattr(doc, "create_time", None) else None, "_updateTime": getattr(doc, "update_time", None).isoformat() if getattr(doc, "update_time", None) else None, "fields": converted}

def walk_collection(col_ref, parent_doc_path=None) -> dict:
    col_path = f"{parent_doc_path}/{col_ref.id}" if parent_doc_path else col_ref.id
    out = {"_collection": col_path, "documents": []}
    for doc in col_ref.stream():
        entry = _doc_to_serializable(doc)
        subs = []
        for sub in doc.reference.collections():
            subs.append(walk_collection(sub, parent_doc_path=doc.reference.path))
        if subs:
            entry["_subcollections"] = subs
        out["documents"].append(entry)
    return out

def dump_firestore(credentials_path: str, project_id: str, only_col_prefixes: t.List[str]=None) -> dict:
    cred = credentials.Certificate(credentials_path)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred, {"projectId": project_id} if project_id else None)
    db = firestore.client()
    root = {"_type": "firestoreDump", "projectId": project_id, "exportedAt": dt.datetime.utcnow().isoformat() + "Z", "rootCollections": []}
    for col in db.collections():
        name = col.id
        if only_col_prefixes and not any(name.startswith(pfx) for pfx in only_col_prefixes):
            continue
        root["rootCollections"].append(walk_collection(col))
    return root

def prefix_dir_name(prefix: str) -> str:
    p = prefix.strip("/")
    if p == "users": return "users_avatars"
    if p == "contestants": return "contestants_avatars"
    return p if p else "root"

def list_and_download_blobs(credentials_path: str, bucket_name: str, prefixes: t.List[str], download_root: Path, max_per_prefix: int=0) -> dict:
    if not HAS_GCS:
        return {"_type": "storageProbe", "enabled": False, "reason": "google-cloud-storage not installed"}
    client = gcs.Client.from_service_account_json(credentials_path)
    bucket = client.bucket(bucket_name)
    report = {"_type": "storageProbe", "projectId": PROJECT_ID, "bucket": bucket.name, "exportedAt": dt.datetime.utcnow().isoformat() + "Z", "prefixReports": []}
    prefixes = prefixes or [""]
    for pfx in prefixes:
        folder = download_root / prefix_dir_name(pfx); folder.mkdir(parents=True, exist_ok=True)
        names = []; count = 0
        for blob in client.list_blobs(bucket.name, prefix=pfx):
            name = blob.name; names.append(name)
            if not name.endswith("/"):
                dest = folder / Path(name).name; blob.download_to_filename(str(dest))
            count += 1
            if max_per_prefix > 0 and count >= max_per_prefix: break
        report["prefixReports"].append({"prefix": pfx, "objectNames": names, "countListed": len(names), "truncated": (max_per_prefix > 0 and len(names) >= max_per_prefix)})
    return report

def _walk_docs(col_dump: dict):
    for d in col_dump.get("documents", []) or []:
        yield d
        for sub in d.get("_subcollections", []) or []:
            for x in _walk_docs(sub): yield x

def compute_metrics(fs_dump: dict) -> dict:
    results = season_picks = weekly_picks = 0
    per_user_weekly = {}
    for col in fs_dump.get("rootCollections", []):
        for d in _walk_docs(col):
            p = d.get("_path","")
            if "/results/" in p: results += 1
            if "/seasonPicks/" in p: season_picks += 1
            if "/weeklyPicks/" in p and "/episodes/" in p:
                weekly_picks += 1
                # capture user id if present: seasons/<sid>/weeklyPicks/<uid>/episodes/<eid>
                parts = p.split("/")
                try:
                    ui = parts.index("weeklyPicks")+1
                    uid = parts[ui]
                    per_user_weekly[uid] = per_user_weekly.get(uid, 0) + 1
                except Exception:
                    pass
    return {"results": results, "seasonPicks": season_picks, "weeklyPicks": weekly_picks, "weeklyPicksByUser": per_user_weekly}

def write_summary_file(snap_dir: Path, kind: str, metrics: dict):
    lines = []
    lines.append(f"# Firebase Snapshot Summary\n")
    lines.append(f"**Kind**: {kind}")
    lines.append(f"**When**: {dt.datetime.utcnow().isoformat()}Z")
    lines.append("")
    lines.append("## Firestore")
    lines.append(f"- Results docs: {metrics.get('results',0)}")
    lines.append(f"- Season picks docs: {metrics.get('seasonPicks',0)}")
    lines.append(f"- Weekly picks docs: {metrics.get('weeklyPicks',0)}")
    by_user = metrics.get("weeklyPicksByUser") or {}
    if by_user:
        lines.append("  - Weekly picks by user:")
        for u, n in sorted(by_user.items()):
            lines.append(f"    - {u}: {n}")
    else:
        lines.append("  - Weekly picks by user: (none)")

    # Storage section: summarize folder contents if present
    users_dir = snap_dir / "users_avatars"
    cont_dir = snap_dir / "contestants_avatars"
    lines.append("")
    lines.append("## Storage (local snapshot folders)")
    lines.append(f"- users_avatars/: {len(list(users_dir.glob('*')))} files" if users_dir.exists() else "- users_avatars/: (missing)")
    lines.append(f"- contestants_avatars/: {len(list(cont_dir.glob('*')))} files" if cont_dir.exists() else "- contestants_avatars/: (missing)")

    (snap_dir / "snapshot_summary.md").write_text("\n".join(lines), encoding="utf-8")

def make_snapshot_dir(base_dir: Path, run_key: str) -> Path:
    ts = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    snap_dir = base_dir / f"snapshot_{run_key}_{ts}"
    snap_dir.mkdir(parents=True, exist_ok=True); return snap_dir

def main():
    base_dir = Path(SNAPSHOTS_ROOT); base_dir.mkdir(parents=True, exist_ok=True)
    print("\n=== Snapshot Tool ===")
    print("1) Dry — Firestore JSON only")
    print("2) Full — Firestore JSON + download Storage blobs")
    print("3) Only collection 'seasons'")
    print(f"4) Only bucket: {DEFAULT_BUCKET}")
    choice = input("\nChoose run type [1-4]: ").strip()

    if choice == "1":
        fs_dump = dump_firestore(CREDENTIALS_PATH, PROJECT_ID, None)

        added = augment_with_weekly_picks_via_collection_group(firestore.client(), fs_dump)
        if added > 0:
            print(f"Included {added} weekly-pick episode docs via collection-group (parent docs were missing).")

        metrics = compute_metrics(fs_dump)
        if metrics["results"] > 0 and metrics["weeklyPicks"] == 0:
            print("WARNING: Results exist but no weekly picks found. VO/IM/RM scoring won't restore.")
            if not input("Continue with dry snapshot? [y/N]: ").strip().lower().startswith("y"): return
        snap_dir = make_snapshot_dir(base_dir, "dry")
        storage_report = {"_type": "storageProbe", "enabled": False, "reason": "dry"}
        (snap_dir/"snapshot.json").write_text(json.dumps({"_type":"firebaseSnapshot","projectId":PROJECT_ID,"exportedAt":dt.datetime.utcnow().isoformat()+"Z","kind":"snapshot_dry","metrics":metrics,"firestore":fs_dump,"storage":storage_report}, indent=2), encoding="utf-8")
        write_summary_file(snap_dir, "snapshot_dry", metrics)
        print(f"\nSnapshot (dry) saved to: {snap_dir}\n")

    elif choice == "2":
        fs_dump = dump_firestore(CREDENTIALS_PATH, PROJECT_ID, None)

        added = augment_with_weekly_picks_via_collection_group(firestore.client(), fs_dump)
        if added > 0:
            print(f"Included {added} weekly-pick episode docs via collection-group (parent docs were missing).")

        metrics = compute_metrics(fs_dump)
        if metrics["results"] > 0 and metrics["weeklyPicks"] == 0:
            print("WARNING: Results exist but no weekly picks found. VO/IM/RM scoring won't restore.")
            if not input("Continue with FULL snapshot? [y/N]: ").strip().lower().startswith("y"): return
        snap_dir = make_snapshot_dir(base_dir, "full")
        storage_report = list_and_download_blobs(CREDENTIALS_PATH, DEFAULT_BUCKET, DEFAULT_PREFIXES, snap_dir)
        (snap_dir/"snapshot.json").write_text(json.dumps({"_type":"firebaseSnapshot","projectId":PROJECT_ID,"exportedAt":dt.datetime.utcnow().isoformat()+"Z","kind":"snapshot_full","metrics":metrics,"firestore":fs_dump,"storage":storage_report}, indent=2), encoding="utf-8")
        write_summary_file(snap_dir, "snapshot_full", metrics)
        print(f"\nSnapshot (full) saved to: {snap_dir}\n")

    elif choice == "3":
        fs_dump = dump_firestore(CREDENTIALS_PATH, PROJECT_ID, ["seasons"])

        added = augment_with_weekly_picks_via_collection_group(firestore.client(), fs_dump)
        if added > 0:
            print(f"Included {added} weekly-pick episode docs via collection-group (parent docs were missing).")

        metrics = compute_metrics(fs_dump)
        snap_dir = make_snapshot_dir(base_dir, "seasons")
        storage_report = {"_type": "storageProbe", "enabled": False, "reason": "only_seasons"}
        (snap_dir/"snapshot.json").write_text(json.dumps({"_type":"firebaseSnapshot","projectId":PROJECT_ID,"exportedAt":dt.datetime.utcnow().isoformat()+"Z","kind":"snapshot_seasons","metrics":metrics,"firestore":fs_dump,"storage":storage_report}, indent=2), encoding="utf-8")
        write_summary_file(snap_dir, "snapshot_seasons", metrics)
        print(f"\nSnapshot (only seasons) saved to: {snap_dir}\n")

    elif choice == "4":
        prefixes = input(f"Enter prefixes (comma sep) [default: {', '.join(DEFAULT_PREFIXES)}]: ").strip()
        pfx_list = [p.strip() if p.strip().endswith('/') else p.strip() + '/' for p in prefixes.split(",")] if prefixes else DEFAULT_PREFIXES
        snap_dir = make_snapshot_dir(base_dir, "bucket")
        storage_report = list_and_download_blobs(CREDENTIALS_PATH, DEFAULT_BUCKET, pfx_list, snap_dir)
        (snap_dir/"snapshot.json").write_text(json.dumps({"_type":"firebaseSnapshot","projectId":PROJECT_ID,"exportedAt":dt.datetime.utcnow().isoformat()+"Z","kind":"snapshot_only_bucket","metrics":{"results":0,"seasonPicks":0,"weeklyPicks":0},"firestore":{"_type":"firestoreDump","projectId":PROJECT_ID,"exportedAt":dt.datetime.utcnow().isoformat()+"Z","rootCollections":[]},"storage":storage_report}, indent=2), encoding="utf-8")
        write_summary_file(snap_dir, "snapshot_only_bucket", {"results":0,"seasonPicks":0,"weeklyPicks":0,"weeklyPicksByUser":{}})
        print(f"\nSnapshot (only bucket) saved to: {snap_dir}\n")
    else:
        print("Unknown choice.")

if __name__ == "__main__":
    main()
