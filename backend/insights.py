import os
import json
from anthropic import Anthropic
from dotenv import load_dotenv

load_dotenv()

_client = Anthropic()


async def generate_insights(events: list) -> dict:
    goal = int(os.environ.get("DAILY_DRINK_GOAL", "8"))
    today_count = len(events)

    total_oz = round(sum(e.get("volume_oz", 8.0) for e in events), 2)
    total_ml = round(sum(e.get("volume_ml", 236.59) for e in events), 2)

    if not events:
        return {
            "today_count": 0,
            "goal": goal,
            "total_oz": 0.0,
            "total_ml": 0.0,
            "message": "No drinks logged today. Stay hydrated!",
            "pattern": "none",
        }

    # Cap at 200 timestamps to keep the prompt well under token limits.
    timestamps = [e["timestamp"] for e in events[:200]]

    response = _client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=256,
        messages=[
            {
                "role": "user",
                "content": (
                    f"You are a hydration assistant. Analyze this drinking data and return ONLY valid JSON.\n\n"
                    f"Today's drink events (UTC timestamps): {timestamps}\n"
                    f"Total drinks today: {today_count}\n"
                    f"Total volume today: {total_oz} oz ({total_ml} ml)\n"
                    f"Daily goal: {goal} drinks\n\n"
                    f"Return a JSON object with:\n"
                    f'- today_count: integer\n'
                    f'- goal: integer\n'
                    f'- total_oz: number (pass through the value provided)\n'
                    f'- total_ml: number (pass through the value provided)\n'
                    f'- message: short motivational message mentioning volume (max 20 words)\n'
                    f'- pattern: one of "regular", "front-loaded", "back-loaded", "irregular", "none"'
                ),
            }
        ],
    )

    fallback = {
        "today_count": today_count,
        "goal": goal,
        "total_oz": total_oz,
        "total_ml": total_ml,
        "message": "Keep up the good work!",
        "pattern": "regular",
    }

    try:
        raw = json.loads(response.content[0].text.strip())
        return _coerce_insights(raw, fallback)
    except (json.JSONDecodeError, Exception):
        return fallback


_VALID_PATTERNS = {"regular", "front-loaded", "back-loaded", "irregular", "none"}


def _coerce_insights(raw: dict, fallback: dict) -> dict:
    """Coerce Claude's response to the expected types, falling back field-by-field."""
    def _int(key: str) -> int:
        try:
            return max(int(raw[key]), 0)
        except (KeyError, TypeError, ValueError):
            return fallback[key]

    def _float(key: str) -> float:
        try:
            return float(raw[key])
        except (KeyError, TypeError, ValueError):
            return fallback[key]

    pattern = raw.get("pattern", fallback["pattern"])
    return {
        "today_count": _int("today_count"),
        "goal": max(_int("goal"), 1),          # guard goal=0 on the server side too
        "total_oz": _float("total_oz"),
        "total_ml": _float("total_ml"),
        "message": str(raw.get("message", fallback["message"]))[:120],
        "pattern": pattern if pattern in _VALID_PATTERNS else fallback["pattern"],
    }
