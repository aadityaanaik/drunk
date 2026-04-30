CREATE TABLE drink_events (
    id          BIGSERIAL        PRIMARY KEY,
    device_id   TEXT             NOT NULL,
    timestamp   TIMESTAMPTZ      NOT NULL,
    confidence  DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    created_at  TIMESTAMPTZ      NOT NULL DEFAULT now(),

    CONSTRAINT uq_drink_events_device_timestamp UNIQUE (device_id, timestamp)
);

-- Supports the "today's events for this device" query (timestamp DESC matches ORDER BY).
CREATE INDEX idx_drink_events_device_timestamp
    ON drink_events (device_id, timestamp DESC);

-- Migration for existing tables:
-- ALTER TABLE drink_events
--     ADD CONSTRAINT uq_drink_events_device_timestamp UNIQUE (device_id, timestamp);
