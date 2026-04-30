# drunk

An Apple Watch app that detects drinking gestures via CoreMotion, syncs events to a FastAPI backend, and returns AI-generated hydration insights via Claude Haiku.

## Architecture

```
Apple Watch                iPhone                   Backend
───────────────────        ───────────────────       ──────────────────────────
CoreMotion (50 Hz)    →    WatchConnectivity    →    FastAPI  →  Supabase
DrinkDetector              PhoneConnectivity         Claude Haiku insights
DrinkStore (buffer)   ←    transferUserInfo    ←    JSON response
```

## Folder Structure

```
drunk/
├── Watch/
│   ├── DrunkApp.swift              # @main entry point
│   ├── AppState.swift              # ObservableObject owning all managers
│   ├── ContentView.swift           # Today count, goal bar, pitch, buttons
│   ├── MotionManager.swift         # CoreMotion at 50 Hz
│   ├── DrinkDetector.swift         # Pitch threshold state machine
│   ├── DrinkStore.swift            # UserDefaults persistence
│   └── BatchSender.swift          # WCSession hourly sync
├── iPhone/
│   ├── DrunkPhoneApp.swift         # @main entry point
│   ├── PhoneContentView.swift      # Relay status screen
│   └── PhoneConnectivityManager.swift  # WCSession → HTTP relay
└── backend/
    ├── main.py                     # FastAPI app, POST /api/events
    ├── database.py                 # Supabase insert + query
    ├── insights.py                 # Claude Haiku insights
    ├── requirements.txt
    ├── schema.sql                  # drink_events table + index
    └── .env.example
```

## Drink Detection

The `DrinkDetector` uses a 4-state machine on wrist pitch (radians):

1. **Idle** → pitch > 0.8 rad → **Raised**
2. **Raised** for ≥ 0.4 s → pitch < 0.3 rad → emit `DrinkEvent` → **Cooldown**
3. **Cooldown** lasts 3 s, then returns to **Idle**

## Backend Setup

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in credentials
uvicorn main:app --reload
```

Run `schema.sql` in your Supabase SQL editor to create the `drink_events` table.

## Requirements

- Xcode 15+ / watchOS 10+ / iOS 17+
- Python 3.11+
- Supabase project
- Anthropic API key
