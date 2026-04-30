import os
import json
import httpx
from dotenv import load_dotenv

load_dotenv()

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "llama3.2")

_PROMPT_TEMPLATE = """\
You are a hydration assistant. Analyze this drinking data and return ONLY valid JSON — no markdown, no explanation.

Today's drink events (UTC timestamps): {timestamps}
Total drinks today: {today_count}
Total volume today: {total_oz} oz ({total_ml} ml)
Daily goal: {goal} drinks

Return a JSON object with exactly these fields:
- today_count: integer
- goal: integer
- total_oz: number (pass through the value provided above)
- total_ml: number (pass through the value provided above)
- message: short motivational message mentioning volume (max 20 words)
- pattern: one of "regular", "front-loaded", "back-loaded", "irregular", "none"
"""


async def _ollama_chat(prompt: str) -> str:
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            f"{OLLAMA_URL}/api/chat",
            json={
                "model": OLLAMA_MODEL,
                "messages": [{"role": "user", "content": prompt}],
                "stream": False,
                "format": "json",   # Ollama JSON mode — forces valid JSON output
            },
        )
        response.raise_for_status()
        return response.json()["message"]["content"]


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

    # Cap at 200 timestamps to keep the prompt well under context limits.
    timestamps = [e["timestamp"] for e in events[:200]]

    fallback = {
        "today_count": today_count,
        "goal": goal,
        "total_oz": total_oz,
        "total_ml": total_ml,
        "message": "Keep up the good work!",
        "pattern": "regular",
    }

    try:
        prompt = _PROMPT_TEMPLATE.format(
            timestamps=timestamps,
            today_count=today_count,
            total_oz=total_oz,
            total_ml=total_ml,
            goal=goal,
        )
        raw_text = await _ollama_chat(prompt)
        raw = json.loads(raw_text)
        return _coerce_insights(raw, fallback)
    except Exception:
        return fallback


_VALID_PATTERNS = {"regular", "front-loaded", "back-loaded", "irregular", "none"}


def _coerce_insights(raw: dict, fallback: dict) -> dict:
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
        "goal": max(_int("goal"), 1),
        "total_oz": _float("total_oz"),
        "total_ml": _float("total_ml"),
        "message": str(raw.get("message", fallback["message"]))[:120],
        "pattern": pattern if pattern in _VALID_PATTERNS else fallback["pattern"],
    }
