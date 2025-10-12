"""Seed Survivus Firestore data from the built-in mock configuration.

This script mirrors the structure that `FirestoreLeagueRepository` expects so
that you can quickly bootstrap a Firebase project for local development.

Usage:
    python seed_firestore.py --credentials path/to/service-account.json \
        --project my-firebase-project

By default the script targets the season id used in the app (`season-001`) and
will upsert documents. Pass `--wipe-first` to delete any existing documents for
that season before seeding new data.
"""
from __future__ import annotations

import argparse
import datetime as dt
from dataclasses import dataclass, field
from typing import Iterable, List

import firebase_admin
from firebase_admin import credentials, firestore


SEASON_ID = "season-001"


@dataclass(frozen=True)
class Contestant:
    id: str
    name: str
    tribe: str | None = None


@dataclass(frozen=True)
class Episode:
    id: int
    air_date: dt.datetime
    title: str
    is_merge_episode: bool = False


@dataclass(frozen=True)
class PhaseCategory:
    id: str
    name: str
    column_id: str
    total_picks: int
    points_per_correct_pick: int | None
    is_locked: bool


@dataclass(frozen=True)
class Phase:
    id: str
    name: str
    sort_index: int
    categories: List[PhaseCategory] = field(default_factory=list)


@dataclass(frozen=True)
class SeasonState:
    active_phase_id: str
    activated_phase_ids: List[str]


@dataclass(frozen=True)
class EpisodeResult:
    id: int
    immunity_winners: List[str]
    voted_out: List[str]


def build_seed_data(season_doc_id: str = SEASON_ID, base_date: dt.datetime | None = None) -> dict:
    """Return the full Firestore payload for the default mock season."""
    if base_date is None:
        base_date = dt.datetime(2024, 2, 7, 0, 0, tzinfo=dt.timezone.utc)

    contestants = [
        Contestant("courtney_yates", "Courtney Yates"),
        Contestant("todd_herzog", "Todd Herzog"),
        Contestant("boston_rob", "Boston Rob"),
        Contestant("russell_hantz", "Russell Hantz"),
        Contestant("john_cochran", "John Cochran"),
        Contestant("tony_vlachos", "Tony Vlachos"),
        Contestant("q", "Q"),
        Contestant("eva_erickson", "Eva Erickson"),
        Contestant("mitch_guerra", "Mitch Guerra"),
        Contestant("erik_reichenbach", "Erik Reichenbach"),
        Contestant("yul_kwon", "Yul Kwon"),
        Contestant("ozzy_lusth", "Ozzy Lusth"),
        Contestant("parvati_shallow", "Parvati Shallow"),
        Contestant("jonathan_penner", "Jonathan Penner"),
        Contestant("nate_gonzalez", "Nate Gonzalez"),
        Contestant("chicken_morris", "Chicken Morris"),
        Contestant("frosti_zernow", "Frosti Zernow"),
        Contestant("james_clement", "James Clement"),
        Contestant("denise_martin", "Denise Martin"),
        Contestant("amanda_kimmel", "Amanda Kimmel"),
    ]

    episodes = [
        Episode(1, base_date, "Week 1"),
        Episode(2, base_date + dt.timedelta(days=7), "Week 2"),
    ]

    phases = [
        Phase(
            id="5c5c0e3d-5fde-4736-bf23-257f381c9f16",
            name="Pre-merge",
            sort_index=0,
            categories=[
                PhaseCategory(
                    id="1b1fc3de-0f77-4ab0-b35f-d4cc0af70ea5",
                    name="Mergers",
                    column_id="MG",
                    total_picks=3,
                    points_per_correct_pick=1,
                    is_locked=True,
                ),
                PhaseCategory(
                    id="a0233cb8-1150-4aa0-86ce-9f4dd19971d9",
                    name="Immunity",
                    column_id="IM",
                    total_picks=3,
                    points_per_correct_pick=3,
                    is_locked=False,
                ),
                PhaseCategory(
                    id="7b8d374e-3253-4429-a028-b9df9c3db5a5",
                    name="Voted out",
                    column_id="VO",
                    total_picks=3,
                    points_per_correct_pick=3,
                    is_locked=False,
                ),
            ],
        ),
        Phase(
            id="9d7b1d66-6d83-4c72-b5fe-2f43f144825a",
            name="Post-merge",
            sort_index=1,
            categories=[
                PhaseCategory(
                    id="dfe18761-7248-455f-a6d4-2adbc046d4bb",
                    name="Immunity",
                    column_id="IM",
                    total_picks=2,
                    points_per_correct_pick=5,
                    is_locked=False,
                ),
                PhaseCategory(
                    id="3f4893f2-5b78-4b3d-86b7-74adad77879b",
                    name="Voted out",
                    column_id="VO",
                    total_picks=2,
                    points_per_correct_pick=5,
                    is_locked=False,
                ),
            ],
        ),
        Phase(
            id="14db25df-cdcf-4748-984a-14fa36f5abbe",
            name="Finals",
            sort_index=2,
            categories=[
                PhaseCategory(
                    id="67d860dc-7e9b-4b50-aab0-8f85398b1a24",
                    name="Carried",
                    column_id="CA",
                    total_picks=1,
                    points_per_correct_pick=10,
                    is_locked=False,
                ),
                PhaseCategory(
                    id="d6a8b84e-9a20-49a8-9f56-7f8999e6c5f6",
                    name="Fire",
                    column_id="FI",
                    total_picks=2,
                    points_per_correct_pick=10,
                    is_locked=False,
                ),
                PhaseCategory(
                    id="af386874-b48f-44a5-9176-0680ff6b59b4",
                    name="Fire Winner",
                    column_id="FW",
                    total_picks=1,
                    points_per_correct_pick=15,
                    is_locked=False,
                ),
                PhaseCategory(
                    id="1ea12183-1c7b-4f42-8ccd-d6a266cb14d5",
                    name="Sole Survivor",
                    column_id="SS",
                    total_picks=1,
                    points_per_correct_pick=25,
                    is_locked=False,
                ),
            ],
        ),
    ]

    state = SeasonState(
        active_phase_id=phases[0].id,
        activated_phase_ids=[phase.id for phase in phases],
    )

    results = [
        EpisodeResult(
            id=1,
            immunity_winners=["q"],
            voted_out=["todd_herzog"],
        ),
        EpisodeResult(
            id=2,
            immunity_winners=["eva_erickson"],
            voted_out=["boston_rob"],
        ),
    ]

    users = {
        "u1": {"displayName": "Zac", "avatarAssetName": "zac"},
        "u2": {"displayName": "Sam", "avatarAssetName": "mace"},
        "u3": {"displayName": "Chris", "avatarAssetName": "chris"},
        "u4": {"displayName": "Liz", "avatarAssetName": "liz"},
    }

    season_picks = {
        "u1": {
            "mergePicks": ["q", "eva_erickson", "tony_vlachos", "john_cochran"],
            "finalThreePicks": ["eva_erickson", "tony_vlachos", "john_cochran"],
            "winnerPick": "tony_vlachos",
        },
        "u2": {
            "mergePicks": ["parvati_shallow", "john_cochran", "boston_rob", "courtney_yates"],
            "finalThreePicks": ["john_cochran", "parvati_shallow", "ozzy_lusth"],
            "winnerPick": "john_cochran",
        },
        "u3": {
            "mergePicks": ["john_cochran", "ozzy_lusth", "russell_hantz", "denise_martin"],
            "finalThreePicks": ["ozzy_lusth", "denise_martin", "eva_erickson"],
            "winnerPick": "denise_martin",
        },
        "u4": {
            "mergePicks": ["amanda_kimmel", "yul_kwon", "erik_reichenbach", "chicken_morris"],
            "finalThreePicks": ["amanda_kimmel", "yul_kwon", "jonathan_penner"],
            "winnerPick": "amanda_kimmel",
        },
    }

    weekly_picks = {
        "u1": {
            1: {
                "remain": ["q", "eva_erickson", "tony_vlachos", "john_cochran"],
                "votedOut": ["todd_herzog"],
                "immunity": ["q"],
            },
            2: {
                "remain": ["eva_erickson", "tony_vlachos", "john_cochran"],
                "votedOut": ["boston_rob"],
                "immunity": ["eva_erickson"],
            },
        },
        "u2": {
            1: {
                "remain": ["parvati_shallow", "john_cochran", "ozzy_lusth"],
                "votedOut": ["russell_hantz"],
                "immunity": ["john_cochran"],
            },
            2: {
                "remain": ["parvati_shallow", "john_cochran", "ozzy_lusth"],
                "votedOut": ["eva_erickson"],
                "immunity": ["ozzy_lusth"],
            },
        },
        "u3": {
            1: {
                "remain": ["john_cochran", "ozzy_lusth", "denise_martin"],
                "votedOut": ["tony_vlachos"],
                "immunity": ["denise_martin"],
            },
            2: {
                "remain": ["john_cochran", "denise_martin"],
                "votedOut": ["mitch_guerra"],
                "immunity": ["john_cochran"],
            },
        },
        "u4": {
            1: {
                "remain": ["amanda_kimmel", "yul_kwon", "erik_reichenbach"],
                "votedOut": ["q"],
                "immunity": ["amanda_kimmel"],
            },
            2: {
                "remain": ["amanda_kimmel", "yul_kwon", "erik_reichenbach"],
                "votedOut": ["erik_reichenbach"],
                "immunity": ["yul_kwon"],
            },
        },
    }

    config_payload = {
        "seasonId": season_doc_id,
        "name": "Mock Season",
        "contestants": [contestant.__dict__ for contestant in contestants],
        "episodes": [
            {
                "id": episode.id,
                "airDate": episode.air_date,
                "title": episode.title,
                "isMergeEpisode": episode.is_merge_episode,
            }
            for episode in episodes
        ],
        "weeklyPickCapsPreMerge": {"remain": 3, "votedOut": 3, "immunity": 3},
        "weeklyPickCapsPostMerge": {"remain": 3, "votedOut": 3, "immunity": None},
        "lockHourUTC": 23,
    }

    phase_payloads = [
        {
            "id": phase.id,
            "name": phase.name,
            "sortIndex": phase.sort_index,
            "categories": [category.__dict__ for category in phase.categories],
        }
        for phase in phases
    ]

    state_payload = {
        "activePhaseId": state.active_phase_id,
        "activatedPhaseIds": state.activated_phase_ids,
    }

    result_payloads = {
        str(result.id): {
            "immunityWinners": result.immunity_winners,
            "votedOut": result.voted_out,
        }
        for result in results
    }

    return {
        "config": config_payload,
        "state": state_payload,
        "phases": phase_payloads,
        "results": result_payloads,
        "users": users,
        "season_picks": season_picks,
        "weekly_picks": weekly_picks,
    }


def wipe_season(client: firestore.Client, season_id: str) -> None:
    season_ref = client.collection("seasons").document(season_id)
    if not season_ref.get().exists:
        return

    def _delete_collection(doc_refs: Iterable[firestore.DocumentReference]):
        for doc_ref in doc_refs:
            for subcollection in doc_ref.collections():
                _delete_collection(subcollection.stream())
            doc_ref.delete()

    for collection_name in ["state", "phases", "results", "users", "seasonPicks", "weeklyPicks"]:
        collection_ref = season_ref.collection(collection_name)
        _delete_collection(collection_ref.stream())

    season_ref.delete()


def seed_firestore(client: firestore.Client, season_id: str, *, wipe_first: bool = False) -> None:
    if wipe_first:
        wipe_season(client, season_id)

    data = build_seed_data(season_id)
    season_ref = client.collection("seasons").document(season_id)
    season_ref.set(data["config"], merge=True)

    state_ref = season_ref.collection("state").document("current")
    state_ref.set(data["state"], merge=True)

    for index, phase in enumerate(data["phases"]):
        phase_ref = season_ref.collection("phases").document(phase["id"])
        payload = dict(phase)
        payload.setdefault("sortIndex", index)
        phase_ref.set(payload, merge=True)

    for episode_id, payload in data["results"].items():
        result_ref = season_ref.collection("results").document(episode_id)
        result_ref.set(payload, merge=True)

    for user_id, payload in data["users"].items():
        user_ref = season_ref.collection("users").document(user_id)
        user_ref.set(payload, merge=True)

    for user_id, payload in data["season_picks"].items():
        picks_ref = season_ref.collection("seasonPicks").document(user_id)
        picks_ref.set(payload, merge=True)

    for user_id, episodes in data["weekly_picks"].items():
        weekly_ref = season_ref.collection("weeklyPicks").document(user_id)
        weekly_ref.set({"userId": user_id}, merge=True)
        for episode_id, picks in episodes.items():
            episode_ref = weekly_ref.collection("episodes").document(str(episode_id))
            episode_ref.set(picks, merge=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed Firestore with Survivus mock data")
    parser.add_argument("--credentials", required=True, help="Path to a Firebase service account key JSON file")
    parser.add_argument(
        "--project",
        help="Override the Firebase project id (defaults to the id embedded in the service account)",
    )
    parser.add_argument(
        "--season-id",
        default=SEASON_ID,
        help=f"Firestore season document id to seed (default: {SEASON_ID})",
    )
    parser.add_argument(
        "--wipe-first",
        action="store_true",
        help="Delete the target season before writing new data",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    cred = credentials.Certificate(args.credentials)
    firebase_admin.initialize_app(cred, {"projectId": args.project} if args.project else None)

    client = firestore.client()
    seed_firestore(client, args.season_id, wipe_first=args.wipe_first)
    print(f"Seeded season '{args.season_id}' into project '{client.project}'.")


if __name__ == "__main__":
    main()
