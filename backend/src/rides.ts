import { haversineMeters, quoteFare, type FareQuote, type LatLng } from "./fare";
import {
  planSimulation,
  projectPosition,
  type RideStatus,
  type SimulationPlan,
} from "./simulate";

export type { SimulationPlan };

export interface DriverRow {
  id: string;
  name: string;
  vehicle: string;
  color: string;
  plate: string;
  lat: number;
  lng: number;
  status: "available" | "on_ride";
}

export interface RideRow {
  id: string;
  rider_name: string;
  pickup_lat: number;
  pickup_lng: number;
  dropoff_lat: number;
  dropoff_lng: number;
  pickup_label: string;
  dropoff_label: string;
  distance_meters: number;
  duration_seconds: number;
  fare_cents: number;
  base_cents: number;
  distance_cents: number;
  time_cents: number;
  booking_cents: number;
  minimum_applied: number;
  currency: string;
  status: RideStatus;
  driver_id: string;
  driver_start_lat: number;
  driver_start_lng: number;
  to_pickup_ms: number;
  dwell_ms: number;
  trip_ms: number;
  started_at: string;
  created_at: string;
  updated_at: string;
}

export interface PublicDriver {
  id: string;
  name: string;
  vehicle: string;
  color: string;
  plate: string;
  lat: number;
  lng: number;
  status: DriverRow["status"];
}

export interface PublicRide {
  id: string;
  riderName: string;
  pickup: { lat: number; lng: number; label: string };
  dropoff: { lat: number; lng: number; label: string };
  distanceMeters: number;
  durationSeconds: number;
  fareCents: number;
  currency: string;
  breakdown: FareQuote["breakdown"];
  status: RideStatus;
  driverId: string;
  startedAt: string;
  createdAt: string;
  updatedAt: string;
  playback: SimulationPlan;
}

export interface TrackPayload {
  ride: PublicRide;
  driver: PublicDriver;
  progress: number;
  etaSeconds: number;
  simulated: true;
  serverTime: string;
}

const RIDE_COLUMNS = `id, rider_name, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
  pickup_label, dropoff_label, distance_meters, duration_seconds, fare_cents,
  base_cents, distance_cents, time_cents, booking_cents, minimum_applied, currency,
  status, driver_id, driver_start_lat, driver_start_lng, to_pickup_ms, dwell_ms,
  trip_ms, started_at, created_at, updated_at`;

export async function listDrivers(db: D1Database): Promise<PublicDriver[]> {
  const result = await db
    .prepare(
      `SELECT id, name, vehicle, color, plate, lat, lng, status
       FROM drivers ORDER BY name`,
    )
    .all<DriverRow>();
  return result.results.map(presentDriver);
}

export async function listRides(
  db: D1Database,
  limit: number,
  nowMs: number,
): Promise<PublicRide[]> {
  await settleExpiredRides(db, nowMs);
  const result = await db
    .prepare(
      `SELECT ${RIDE_COLUMNS} FROM rides ORDER BY created_at DESC LIMIT ?`,
    )
    .bind(limit)
    .all<RideRow>();
  return result.results.map((row) => presentRide(row, nowMs));
}

export async function getRide(
  db: D1Database,
  id: string,
  nowMs: number,
): Promise<PublicRide | null> {
  await settleExpiredRides(db, nowMs);
  const row = await findRide(db, id);
  return row ? presentRide(row, nowMs) : null;
}

export async function createRide(
  db: D1Database,
  input: {
    riderName: string;
    pickup: LatLng;
    dropoff: LatLng;
    pickupLabel: string;
    dropoffLabel: string;
    nowMs: number;
  },
): Promise<PublicRide> {
  await settleExpiredRides(db, input.nowMs);
  const distance = haversineMeters(input.pickup, input.dropoff);
  if (distance < 30) {
    throw new RideError(
      400,
      "points_too_close",
      "Pickup and dropoff need to be at least 30 meters apart.",
    );
  }
  const quote = quoteFare(distance);
  const drivers = await db
    .prepare(
      `SELECT id, name, vehicle, color, plate, lat, lng, status
       FROM drivers WHERE status = 'available'`,
    )
    .all<DriverRow>();
  if (drivers.results.length === 0) {
    throw new RideError(
      409,
      "no_drivers",
      "Every demo driver is already on a ride. Try again in a moment.",
    );
  }
  const nearest = drivers.results.reduce((best, driver) => {
    const bestMeters = haversineMeters(input.pickup, best);
    const nextMeters = haversineMeters(input.pickup, driver);
    return nextMeters < bestMeters ? driver : best;
  });
  const plan = planSimulation(nearest, input.pickup, input.dropoff);
  const nowIso = new Date(input.nowMs).toISOString();
  const id = crypto.randomUUID();
  const claimed = await db
    .prepare(
      `UPDATE drivers SET status = 'on_ride' WHERE id = ? AND status = 'available'`,
    )
    .bind(nearest.id)
    .run();
  if ((claimed.meta.changes ?? 0) !== 1) {
    throw new RideError(
      409,
      "driver_taken",
      "That driver was just assigned. Request the ride again.",
    );
  }
  await db
    .prepare(
      `INSERT INTO rides (
        id, rider_name, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
        pickup_label, dropoff_label, distance_meters, duration_seconds, fare_cents,
        base_cents, distance_cents, time_cents, booking_cents, minimum_applied,
        currency, status, driver_id, driver_start_lat, driver_start_lng,
        to_pickup_ms, dwell_ms, trip_ms, started_at, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
    .bind(
      id,
      input.riderName,
      input.pickup.lat,
      input.pickup.lng,
      input.dropoff.lat,
      input.dropoff.lng,
      input.pickupLabel,
      input.dropoffLabel,
      quote.distanceMeters,
      quote.durationSeconds,
      quote.fareCents,
      quote.breakdown.baseCents,
      quote.breakdown.distanceCents,
      quote.breakdown.timeCents,
      quote.breakdown.bookingCents,
      quote.breakdown.minimumApplied ? 1 : 0,
      quote.currency,
      "en_route_pickup",
      nearest.id,
      nearest.lat,
      nearest.lng,
      plan.toPickupMs,
      plan.dwellMs,
      plan.tripMs,
      nowIso,
      nowIso,
      nowIso,
    )
    .run();
  const created = await findRide(db, id);
  if (!created) {
    throw new RideError(500, "persist_failed", "The ride could not be stored.");
  }
  return presentRide(created, input.nowMs);
}

export async function syncRide(
  db: D1Database,
  id: string,
  nowMs: number,
): Promise<TrackPayload | null> {
  await settleExpiredRides(db, nowMs);
  const row = await findRide(db, id);
  if (!row) return null;
  const driver = await findDriver(db, row.driver_id);
  if (!driver) {
    throw new RideError(500, "missing_driver", "Assigned driver is missing.");
  }
  if (row.status === "cancelled" || row.status === "completed") {
    return {
      ride: presentRide(row, nowMs),
      driver: presentDriver(driver),
      progress: row.status === "completed" ? 1 : 0,
      etaSeconds: 0,
      simulated: true,
      serverTime: new Date(nowMs).toISOString(),
    };
  }
  const projected = projectPosition({
    driver: { lat: row.driver_start_lat, lng: row.driver_start_lng },
    pickup: { lat: row.pickup_lat, lng: row.pickup_lng },
    dropoff: { lat: row.dropoff_lat, lng: row.dropoff_lng },
    plan: planOf(row),
    startedAtMs: Date.parse(row.started_at),
    nowMs,
  });
  const nowIso = new Date(nowMs).toISOString();
  if (projected.status === "completed") {
    await markCompleted(db, row, nowIso);
  } else {
    await db.batch([
      db
        .prepare(
          `UPDATE rides SET status = ?, updated_at = ? WHERE id = ? AND status NOT IN ('completed', 'cancelled')`,
        )
        .bind(projected.status, nowIso, row.id),
      db
        .prepare(`UPDATE drivers SET lat = ?, lng = ? WHERE id = ?`)
        .bind(projected.lat, projected.lng, row.driver_id),
    ]);
  }
  const freshRide = await findRide(db, id);
  const freshDriver = await findDriver(db, row.driver_id);
  if (!freshRide || !freshDriver) return null;
  return {
    ride: presentRide(freshRide, nowMs),
    driver: presentDriver(freshDriver),
    progress: projected.progress,
    etaSeconds: projected.etaSeconds,
    simulated: true,
    serverTime: new Date(nowMs).toISOString(),
  };
}

export async function cancelRide(
  db: D1Database,
  id: string,
  nowMs: number,
): Promise<PublicRide | null> {
  await settleExpiredRides(db, nowMs);
  const row = await findRide(db, id);
  if (!row) return null;
  if (row.status === "cancelled") return presentRide(row, nowMs);
  if (row.status === "completed" || row.status === "on_trip") {
    throw new RideError(
      409,
      "cannot_cancel",
      row.status === "completed"
        ? "This ride is already finished."
        : "The trip has started, so this demo ride can no longer be cancelled.",
    );
  }
  const projected = projectPosition({
    driver: { lat: row.driver_start_lat, lng: row.driver_start_lng },
    pickup: { lat: row.pickup_lat, lng: row.pickup_lng },
    dropoff: { lat: row.dropoff_lat, lng: row.dropoff_lng },
    plan: planOf(row),
    startedAtMs: Date.parse(row.started_at),
    nowMs,
  });
  if (projected.status === "on_trip" || projected.status === "completed") {
    throw new RideError(
      409,
      "cannot_cancel",
      "The trip has started, so this demo ride can no longer be cancelled.",
    );
  }
  const nowIso = new Date(nowMs).toISOString();
  await db.batch([
    db
      .prepare(
        `UPDATE rides SET status = 'cancelled', updated_at = ?
         WHERE id = ? AND status IN ('en_route_pickup', 'arriving')`,
      )
      .bind(nowIso, id),
    db
      .prepare(
        `UPDATE drivers SET status = 'available', lat = ?, lng = ? WHERE id = ?`,
      )
      .bind(projected.lat, projected.lng, row.driver_id),
  ]);
  const fresh = await findRide(db, id);
  return fresh ? presentRide(fresh, nowMs) : null;
}

export function presentRide(row: RideRow, nowMs: number): PublicRide {
  const status = displayedStatus(row, nowMs);
  return {
    id: row.id,
    riderName: row.rider_name,
    pickup: {
      lat: row.pickup_lat,
      lng: row.pickup_lng,
      label: row.pickup_label,
    },
    dropoff: {
      lat: row.dropoff_lat,
      lng: row.dropoff_lng,
      label: row.dropoff_label,
    },
    distanceMeters: row.distance_meters,
    durationSeconds: row.duration_seconds,
    fareCents: row.fare_cents,
    currency: row.currency,
    breakdown: {
      baseCents: row.base_cents,
      distanceCents: row.distance_cents,
      timeCents: row.time_cents,
      bookingCents: row.booking_cents,
      minimumApplied: row.minimum_applied === 1,
    },
    status,
    driverId: row.driver_id,
    startedAt: row.started_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    playback: planOf(row),
  };
}

export function presentDriver(row: DriverRow): PublicDriver {
  return {
    id: row.id,
    name: row.name,
    vehicle: row.vehicle,
    color: row.color,
    plate: row.plate,
    lat: row.lat,
    lng: row.lng,
    status: row.status,
  };
}

export class RideError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "RideError";
  }
}

async function settleExpiredRides(db: D1Database, nowMs: number): Promise<void> {
  const active = await db
    .prepare(
      `SELECT ${RIDE_COLUMNS} FROM rides WHERE status NOT IN ('completed', 'cancelled')`,
    )
    .all<RideRow>();
  for (const row of active.results) {
    if (displayedStatus(row, nowMs) === "completed") {
      await markCompleted(db, row, new Date(nowMs).toISOString());
    }
  }
}

async function markCompleted(
  db: D1Database,
  row: RideRow,
  nowIso: string,
): Promise<void> {
  await db.batch([
    db
      .prepare(
        `UPDATE rides SET status = 'completed', updated_at = ?
         WHERE id = ? AND status NOT IN ('completed', 'cancelled')`,
      )
      .bind(nowIso, row.id),
    db
      .prepare(
        `UPDATE drivers SET status = 'available', lat = ?, lng = ? WHERE id = ?`,
      )
      .bind(row.dropoff_lat, row.dropoff_lng, row.driver_id),
  ]);
}

function displayedStatus(row: RideRow, nowMs: number): RideStatus {
  if (row.status === "cancelled" || row.status === "completed") return row.status;
  return projectPosition({
    driver: { lat: row.driver_start_lat, lng: row.driver_start_lng },
    pickup: { lat: row.pickup_lat, lng: row.pickup_lng },
    dropoff: { lat: row.dropoff_lat, lng: row.dropoff_lng },
    plan: planOf(row),
    startedAtMs: Date.parse(row.started_at),
    nowMs,
  }).status;
}

function planOf(row: RideRow): SimulationPlan {
  return {
    toPickupMs: row.to_pickup_ms,
    dwellMs: row.dwell_ms,
    tripMs: row.trip_ms,
  };
}

async function findRide(db: D1Database, id: string): Promise<RideRow | null> {
  return db
    .prepare(`SELECT ${RIDE_COLUMNS} FROM rides WHERE id = ?`)
    .bind(id)
    .first<RideRow>();
}

async function findDriver(db: D1Database, id: string): Promise<DriverRow | null> {
  return db
    .prepare(
      `SELECT id, name, vehicle, color, plate, lat, lng, status FROM drivers WHERE id = ?`,
    )
    .bind(id)
    .first<DriverRow>();
}
