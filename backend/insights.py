import os
import json
from anthropic import Anthropic
from dotenv import load_dotenv

load_dotenv()

_client = Anthropic()


async def generate_insights(events: list) -> dict:
    goal = int(os.environ.get("DAILY_DRINK_GOAL", "8"))
    today_count = len(events)

    if not events:
        return {
            "today_count": 0,
            "goal": goal,
            "message": "No drinks logged today. Stay hydrated!",
            "pattern": "none",
        }

    timestamps = [e["timestamp"] for e in events]

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
                    f"Daily goal: {goal} drinks\n\n"
                    f"Return a JSON object with:\n"
                    f'- today_count: integer\n'
                    f'- goal: integer\n'
                    f'- message: short motivational message (max 20 words)\n'
                    f'- pattern: one of "regular", "front-loaded", "back-loaded", "irregular", "none"'
                ),
            }
        ],
    )

    try:
        return json.loads(response.content[0].text.strip())
    except json.JSONDecodeError:
        return {
            "today_count": today_count,
            "goal": goal,
            "message": "Keep up the good work!",
            "pattern": "regular",
        }
