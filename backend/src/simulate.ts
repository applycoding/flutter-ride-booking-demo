import { haversineMeters, type LatLng } from "./fare";

export const RIDE_STATUSES = [
  "en_route_pickup",
  "arriving",
  "on_trip",
  "completed",
  "cancelled",
] as const;

export type RideStatus = (typeof RIDE_STATUSES)[number];

/** Animated speed. The fare quote uses a realistic pace; playback is faster. */
export const DEMO_METERS_PER_SECOND = 28;
export const MIN_TO_PICKUP_MS = 8_000;
export const ARRIVE_DWELL_MS = 4_000;
export const MIN_TRIP_MS = 10_000;

export interface SimulationPlan {
  toPickupMs: number;
  dwellMs: number;
  tripMs: number;
}

export interface ProjectedPoint {
  lat: number;
  lng: number;
  status: Exclude<RideStatus, "cancelled">;
  progress: number;
  etaSeconds: number;
}

export function planSimulation(
  driver: LatLng,
  pickup: LatLng,
  dropoff: LatLng,
): SimulationPlan {
  const toPickupMeters = haversineMeters(driver, pickup);
  const tripMeters = haversineMeters(pickup, dropoff);
  return {
    toPickupMs: Math.max(
      MIN_TO_PICKUP_MS,
      Math.round((toPickupMeters / DEMO_METERS_PER_SECOND) * 1000),
    ),
    dwellMs: ARRIVE_DWELL_MS,
    tripMs: Math.max(
      MIN_TRIP_MS,
      Math.round((tripMeters / DEMO_METERS_PER_SECOND) * 1000),
    ),
  };
}

export function projectPosition(input: {
  driver: LatLng;
  pickup: LatLng;
  dropoff: LatLng;
  plan: SimulationPlan;
  startedAtMs: number;
  nowMs: number;
}): ProjectedPoint {
  const elapsed = Math.max(0, input.nowMs - input.startedAtMs);
  const { toPickupMs, dwellMs, tripMs } = input.plan;
  if (elapsed < toPickupMs) {
    const progress = toPickupMs === 0 ? 1 : elapsed / toPickupMs;
    return {
      ...lerp(input.driver, input.pickup, progress),
      status: "en_route_pickup",
      progress,
      etaSeconds: Math.ceil((toPickupMs - elapsed) / 1000),
    };
  }
  const afterPickup = elapsed - toPickupMs;
  if (afterPickup < dwellMs) {
    return {
      lat: input.pickup.lat,
      lng: input.pickup.lng,
      status: "arriving",
      progress: 1,
      etaSeconds: Math.ceil((dwellMs - afterPickup) / 1000),
    };
  }
  const tripElapsed = afterPickup - dwellMs;
  if (tripElapsed < tripMs) {
    const progress = tripMs === 0 ? 1 : tripElapsed / tripMs;
    return {
      ...lerp(input.pickup, input.dropoff, progress),
      status: "on_trip",
      progress,
      etaSeconds: Math.ceil((tripMs - tripElapsed) / 1000),
    };
  }
  return {
    lat: input.dropoff.lat,
    lng: input.dropoff.lng,
    status: "completed",
    progress: 1,
    etaSeconds: 0,
  };
}

function lerp(from: LatLng, to: LatLng, progress: number): LatLng {
  const t = clamp01(progress);
  return {
    lat: from.lat + (to.lat - from.lat) * t,
    lng: from.lng + (to.lng - from.lng) * t,
  };
}

function clamp01(value: number): number {
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}
