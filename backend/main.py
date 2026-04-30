from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List

from database import insert_events, get_today_events
from insights import generate_insights

app = FastAPI(title="drunk")


class DrinkEventIn(BaseModel):
    timestamp: float
    confidence: float
    volume_oz: float = 8.0  # fallback for older clients that don't send volume


class EventBatch(BaseModel):
    device_id: str
    events: List[DrinkEventIn]


@app.post("/api/events")
async def receive_events(batch: EventBatch):
    if not batch.events:
        raise HTTPException(status_code=400, detail="No events provided")

    await insert_events(batch.device_id, batch.events)
    today_events = await get_today_events(batch.device_id)
    return await generate_insights(today_events)
