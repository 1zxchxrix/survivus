# Firebase Infrastructure-as-Code Guide

This document shows how to reproduce the Firestore hierarchy that `FirestoreLeagueRepository` expects using the Firebase CLI so that the backend can be versioned and automated alongside the app code.

## Repository-aware Firestore layout

`FirestoreLeagueRepository` watches and writes documents under the following collections:

```
seasons/{seasonId}
  ├── config (document: season root)
  ├── state/current (document)
  ├── phases/{phaseId}
  ├── results/{episodeNumber}
  ├── users/{userId}
  ├── seasonPicks/{userId}
  └── weeklyPicks/{userId}/episodes/{episodeNumber}
```

The Codable payloads live in [`Services/Store/FirestoreLeagueRepository.swift`](../survivus/Services/Store/FirestoreLeagueRepository.swift) and define the exact JSON structure (`SeasonStateDocument`, `PhaseDocument`, `EpisodeResultDocument`, etc.). Keep JSON fixtures aligned with these structs so the Swift client can decode them without runtime migrations.

## Recommended project layout

```
infra/
  firestore/
    seasons/
      season-001/
        season.json             # SeasonConfig payload
        state.json              # SeasonStateDocument payload
        phases.json             # Array of PhaseDocument
        results.json            # Array of EpisodeResultDocument
        users.json              # Array of UserDocument
        seasonPicks.json        # Array of SeasonPicksDocument
        weeklyPicks.json        # Array of WeeklyPicksDocument grouped by user/episode
firebase.json                   # Emulator + deploy targets
firestore.indexes.json          # Composite index definitions
firestore.rules                 # Security rules (optional)
```

Check these files into Git so changes to the backend schema are reviewed the same way as Swift code.

## Bootstrapping Firestore data with the CLI

1. Install and authenticate the Firebase CLI:
   ```bash
   npm install -g firebase-tools
   firebase login
   firebase use <project-id>
   ```

2. Convert the Swift mocks into JSON templates. For example, serialize `SeasonConfig.mock()` into `infra/firestore/seasons/season-001/season.json`:
   ```json
   {
     "id": "season-001",
     "name": "Survivus Season",
     "currentEpisode": 1,
     "contestants": ["Contestant A", "Contestant B"],
     "totalEpisodes": 13
   }
   ```

3. Apply the JSON fixtures with `firebase firestore:documents:set`. A simple shell helper can blast the season hierarchy in one go:
   ```bash
   PROJECT=your-project-id
   SEASON=season-001
   ROOT=infra/firestore/seasons/$SEASON

   firebase firestore:documents:set \
     seasons/$SEASON @"$ROOT/season.json" \
     seasons/$SEASON/state/current @"$ROOT/state.json"

   jq -c '.[]' "$ROOT/phases.json" | while read -r phase; do
     id=$(echo "$phase" | jq -r '.id // .documentId')
     tmp=$(mktemp)
     echo "$phase" > "$tmp"
     firebase firestore:documents:set \
       seasons/$SEASON/phases/$id @"$tmp"
     rm "$tmp"
   done
   ```

   Use `firebase firestore:documents:set --document seasons/$SEASON/results/<episode>` for per-episode results. The CLI accepts multi-write batches when you supply multiple document/value pairs in a single call, so you can script loops to iterate through arrays in your JSON files.

4. Seed nested collections (weekly picks) by iterating users and episodes:
   ```bash
   jq -c '.[]' "$ROOT/weeklyPicks.json" | while read -r entry; do
     user=$(echo "$entry" | jq -r '.userId')
     firebase firestore:documents:set \
       seasons/$SEASON/weeklyPicks/$user "$ROOT/weeklyPicks/$user.json"

     jq -c '.episodes[]' "$ROOT/weeklyPicks/$user.json" | while read -r episode; do
       number=$(echo "$episode" | jq -r '.episodeId')
       tmp=$(mktemp)
       echo "$episode" > "$tmp"
       firebase firestore:documents:set \
         seasons/$SEASON/weeklyPicks/$user/episodes/$number "$tmp"
       rm "$tmp"
     done
   done
   ```

   The script assumes you have one JSON file per user containing an array of weekly episode payloads that match `WeeklyPicksDocument` (i.e. `remain`, `votedOut`, `immunity`, and `categorySelections`).

5. Clean out stale data between runs with `firebase firestore:delete seasons/$SEASON --recursive --force`. This keeps local emulators and staging projects in sync with your latest fixture set.

## Managing indexes and rules

- Define composite indexes in `firestore.indexes.json` and deploy them with:
  ```bash
  firebase deploy --only firestore:indexes
  ```

- Keep security rules in `firestore.rules` (or split per environment) and deploy via:
  ```bash
  firebase deploy --only firestore:rules
  ```

## Automating through CI

Add a CI job that lints the JSON fixtures (e.g. with `jq`), runs `firebase emulators:exec "npm test"` against the emulated data, and finally deploys to staging via `firebase deploy --only firestore:documents`. Because the fixtures are versioned, reviewers can diff backend changes alongside Swift updates.

For production, gate deployments on tags or protected branches so that backend state only updates when the app is ready.

## Advanced workflows

- **gcloud + Management API:** For more complex orchestrations, call the [Firestore Admin API](https://cloud.google.com/firestore/docs/reference/rest) via `gcloud firestore` commands or Google Cloud Workflows. These APIs can create collections/documents from Cloud Build pipelines without storing service account keys locally.
- **Templated data generation:** Use a Swift or Node script to convert the existing `MemoryStore` mock data into the JSON fixture format. Run the generator before commits to keep local preview data and Firestore seeds aligned.
- **Environment overlays:** Store multiple season folders (e.g. `season-001`, `season-002`) or environment-specific overrides (`staging/`, `production/`) so you can reproduce historic seasons or branch new ones without disrupting live data.

With these practices in place, Firestore becomes another piece of infrastructure-as-code, and AI-generated scripts can slot directly into your seeding/deployment workflow.
