# Survivus

Survivus is a SwiftUI companion app for running a casual Survivor fantasy league. It seeds the experience with mock data so you can browse example results, review league picks, and inspect the current table without hooking up a backend or persistence layer yet.

## Features

- **Multi-tab layout** &mdash; The app launches into a tab view that switches between the results feed, league picks, and leaderboard table.
- **Episode results browser** &mdash; The Results tab surfaces a reverse-chronological list of episodes with merge indicators and the recorded immunity and elimination outcomes pulled from the mock data.
- **Pick management** &mdash; The Picks tab renders each player’s season-long and weekly picks, and it exposes editors for the active user’s selections.
- **Live scoring table** &mdash; The Table tab aggregates weekly and season-long scoring using the shared scoring engine to show where every player stands.

## Project structure

```
survivus/
├── survivus.xcodeproj
└── survivus/
    ├── Features/        # SwiftUI screens grouped by domain
    ├── Models/          # Core data types for contestants, episodes, and picks
    ├── Services/        # App state, scoring logic, and store abstractions
    ├── Shared/          # Reusable UI components
    └── Mocks/           # Seed data for local development
```

Key service types keep the UI lightweight:

- `AppState` wires the in-memory store into the SwiftUI environment and exposes the scoring engine derived from the latest results.
- `MemoryStore` holds the mock configuration, user profiles, and picks, and can be swapped for a persistent store in the future.
- `ScoringEngine` centralises scoring rules so both weekly and season-long totals stay consistent across the app.

## Getting started

1. Install the latest Xcode release with SwiftUI support.
2. Open `survivus.xcodeproj` from the repository root.
3. Select the **survivus** app target and run it in the iOS Simulator or on a device.

The project currently ships with an in-memory mock store. On launch, `AppState` loads mock contestants, episodes, and picks so you can explore the interface without signing in or configuring a backend.

### Automating the Firestore backend

When you are ready to move from the in-memory store to Firestore, treat the backend as infrastructure-as-code. The [Firebase infrastructure guide](docs/firebase-infra-as-code.md) outlines the document hierarchy `FirestoreLeagueRepository` expects and shows how to seed that data with the Firebase CLI so that JSON fixtures and indexes can live alongside the Swift sources.

## Roadmap ideas

- Replace the mock `MemoryStore` with a persistent store backed by Core Data so user picks survive restarts.
- Expand the results feed to support more than the first two episodes and add spoiler-safe states for future weeks.
- Flesh out the pick editors to let players add, remove, and lock in their selections against configurable deadlines.

## License

This project is currently unlicensed; add a license file before distributing or publishing the app.
