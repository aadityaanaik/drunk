import os
from datetime import datetime, timezone
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

_client: Client | None = None


def get_client() -> Client:
    global _client
    if _client is None:
        _client = create_client(
            os.environ["SUPABASE_URL"],
            os.environ["SUPABASE_SERVICE_KEY"],
        )
    return _client


ML_PER_OZ = 29.5735


async def insert_events(device_id: str, events) -> None:
    rows = [
        {
            "device_id": device_id,
            "timestamp": datetime.fromtimestamp(e.timestamp, tz=timezone.utc).isoformat(),
            "confidence": e.confidence,
            "volume_oz": e.volume_oz,
            "volume_ml": round(e.volume_oz * ML_PER_OZ, 2),
        }
        for e in events
    ]
    # ignore_duplicates=True → INSERT ... ON CONFLICT DO NOTHING, safe for retries.
    get_client().table("drink_events").upsert(rows, ignore_duplicates=True, on_conflict="device_id,timestamp").execute()


async def get_today_events(device_id: str) -> list:
    today = datetime.now(timezone.utc).date().isoformat()
    result = (
        get_client()
        .table("drink_events")
        .select("timestamp, confidence, volume_oz, volume_ml")
        .eq("device_id", device_id)
        .gte("timestamp", today)
        .order("timestamp", desc=True)
        .execute()
    )
    return result.data
