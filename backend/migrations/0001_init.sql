CREATE TABLE drivers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  vehicle TEXT NOT NULL,
  color TEXT NOT NULL,
  plate TEXT NOT NULL,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('available', 'on_ride'))
);

CREATE TABLE rides (
  id TEXT PRIMARY KEY,
  rider_name TEXT NOT NULL,
  pickup_lat REAL NOT NULL,
  pickup_lng REAL NOT NULL,
  dropoff_lat REAL NOT NULL,
  dropoff_lng REAL NOT NULL,
  pickup_label TEXT NOT NULL,
  dropoff_label TEXT NOT NULL,
  distance_meters INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL,
  fare_cents INTEGER NOT NULL,
  base_cents INTEGER NOT NULL,
  distance_cents INTEGER NOT NULL,
  time_cents INTEGER NOT NULL,
  booking_cents INTEGER NOT NULL,
  minimum_applied INTEGER NOT NULL,
  currency TEXT NOT NULL,
  status TEXT NOT NULL CHECK (
    status IN ('en_route_pickup', 'arriving', 'on_trip', 'completed', 'cancelled')
  ),
  driver_id TEXT NOT NULL,
  driver_start_lat REAL NOT NULL,
  driver_start_lng REAL NOT NULL,
  to_pickup_ms INTEGER NOT NULL,
  dwell_ms INTEGER NOT NULL,
  trip_ms INTEGER NOT NULL,
  started_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (driver_id) REFERENCES drivers (id)
);

CREATE INDEX rides_created_at ON rides (created_at DESC);

-- Four fictional drivers staged around Victoria's inner harbour.
-- The map tiles are real; the people, vehicles, and plates are not.
INSERT INTO drivers (id, name, vehicle, color, plate, lat, lng, status) VALUES
  ('drv_lila', 'Lila Ferris', 'Cedar hatchback', '#1F6F68', 'QY-14B7', 48.42890, -123.36710, 'available'),
  ('drv_omar', 'Omar Vale', 'Sand wagon', '#C4A574', 'QY-28K1', 48.41820, -123.37840, 'available'),
  ('drv_june', 'June Pell', 'Ink sedan', '#243633', 'QY-07M4', 48.42640, -123.35890, 'available'),
  ('drv_nico', 'Nico Adler', 'Coral compact', '#E07A5F', 'QY-33R9', 48.41480, -123.36920, 'available');
