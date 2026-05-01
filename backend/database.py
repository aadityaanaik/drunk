import os
from datetime import datetime, timezone

import asyncpg
from dotenv import load_dotenv

load_dotenv()

ML_PER_OZ = 29.5735

_pool: asyncpg.Pool | None = None


async def get_pool() -> asyncpg.Pool:
    global _pool
    if _pool is None:
        _pool = await asyncpg.create_pool(os.environ["DATABASE_URL"], min_size=1, max_size=10)
    return _pool


async def insert_events(device_id: str, events) -> None:
    pool = await get_pool()
    rows = [
        (
            device_id,
            datetime.fromtimestamp(e.timestamp, tz=timezone.utc),
            e.confidence,
            e.volume_oz,
            round(e.volume_oz * ML_PER_OZ, 2),
        )
        for e in events
    ]
    async with pool.acquire() as conn:
        await conn.executemany(
            """
            INSERT INTO drink_events (device_id, timestamp, confidence, volume_oz, volume_ml)
            VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT (device_id, timestamp) DO NOTHING
            """,
            rows,
        )


async def delete_events(device_id: str, timestamps: list[float]) -> None:
    pool = await get_pool()
    dts = [datetime.fromtimestamp(ts, tz=timezone.utc) for ts in timestamps]
    async with pool.acquire() as conn:
        await conn.execute(
            "DELETE FROM drink_events WHERE device_id = $1 AND timestamp = ANY($2::timestamptz[])",
            device_id,
            dts,
        )


async def get_today_events(device_id: str) -> list:
    pool = await get_pool()
    today = datetime.now(timezone.utc).date()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT timestamp, confidence, volume_oz, volume_ml
            FROM drink_events
            WHERE device_id = $1 AND timestamp >= $2
            ORDER BY timestamp DESC
            """,
            device_id,
            datetime(today.year, today.month, today.day, tzinfo=timezone.utc),
        )
    return [dict(r) for r in rows]
