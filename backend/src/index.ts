import { quoteFare, haversineMeters } from "./fare";
import {
  RequestError,
  coordinateLabel,
  empty,
  error,
  isRecord,
  json,
  readJson,
  readLabel,
  readPoint,
  readRiderName,
} from "./http";
import { RideError, createRide, getRide, listDrivers, listRides } from "./rides";

export { RideTracker } from "./ride_tracker";

type Route =
  | { kind: "health" }
  | { kind: "drivers" }
  | { kind: "estimate" }
  | { kind: "create_ride" }
  | { kind: "list_rides" }
  | { kind: "get_ride"; id: string }
  | { kind: "track"; id: string }
  | { kind: "cancel"; id: string }
  | { kind: "watch"; id: string }
  | { kind: "not_found" };

export function matchRoute(method: string, pathname: string): Route {
  const parts = pathname.split("/").filter((part) => part.length > 0);
  if (parts.length === 1 && parts[0] === "health" && method === "GET") {
    return { kind: "health" };
  }
  if (parts[0] !== "v1") return { kind: "not_found" };
  if (parts.length === 2 && parts[1] === "drivers" && method === "GET") {
    return { kind: "drivers" };
  }
  if (
    parts.length === 3 &&
    parts[1] === "fares" &&
    parts[2] === "estimate" &&
    method === "POST"
  ) {
    return { kind: "estimate" };
  }
  if (parts.length === 2 && parts[1] === "rides" && method === "GET") {
    return { kind: "list_rides" };
  }
  if (parts.length === 2 && parts[1] === "rides" && method === "POST") {
    return { kind: "create_ride" };
  }
  if (parts.length === 3 && parts[1] === "rides" && method === "GET") {
    return { kind: "get_ride", id: decodeURIComponent(parts[2]) };
  }
  if (
    parts.length === 4 &&
    parts[1] === "rides" &&
    parts[3] === "track" &&
    method === "GET"
  ) {
    return { kind: "track", id: decodeURIComponent(parts[2]) };
  }
  if (
    parts.length === 4 &&
    parts[1] === "rides" &&
    parts[3] === "cancel" &&
    method === "POST"
  ) {
    return { kind: "cancel", id: decodeURIComponent(parts[2]) };
  }
  if (
    parts.length === 4 &&
    parts[1] === "rides" &&
    parts[3] === "watch" &&
    method === "GET"
  ) {
    return { kind: "watch", id: decodeURIComponent(parts[2]) };
  }
  return { kind: "not_found" };
}

const handler = {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "OPTIONS") return empty(204);
    try {
      const route = matchRoute(request.method, url.pathname);
      const response = await dispatch(request, env, url, route);
      console.log(
        JSON.stringify({
          msg: "request",
          method: request.method,
          path: url.pathname,
          status: response.status,
        }),
      );
      return response;
    } catch (caught) {
      const response = toErrorResponse(caught);
      console.log(
        JSON.stringify({
          msg: "request_error",
          method: request.method,
          path: url.pathname,
          status: response.status,
        }),
      );
      return response;
    }
  },
} satisfies ExportedHandler<Env>;

export default handler;

async function dispatch(
  request: Request,
  env: Env,
  url: URL,
  route: Route,
): Promise<Response> {
  const nowMs = readNow(url);
  switch (route.kind) {
    case "health":
      return json({ ok: true, service: "quay-rides" });
    case "drivers":
      return json({ drivers: await listDrivers(env.DB) });
    case "estimate":
      return estimate(request);
    case "list_rides":
      return json({ rides: await listRides(env.DB, readLimit(url), nowMs) });
    case "create_ride":
      return create(request, env, nowMs);
    case "get_ride": {
      const ride = await getRide(env.DB, route.id, nowMs);
      if (!ride) return error(404, "not_found", "No ride with that id.");
      return json({ ride });
    }
    case "track":
    case "cancel":
    case "watch":
      return forwardToTracker(request, env, route.id);
    case "not_found":
      return error(404, "not_found", "No route matches that path.");
    default: {
      const unexpected: never = route;
      throw new Error(`Unhandled route ${JSON.stringify(unexpected)}`);
    }
  }
}

async function estimate(request: Request): Promise<Response> {
  const body = await readJson(request);
  if (!isRecord(body)) {
    return error(400, "validation_error", "Body must be a JSON object.");
  }
  const pickup = readPoint(body.pickup, "pickup");
  const dropoff = readPoint(body.dropoff, "dropoff");
  const distance = haversineMeters(pickup, dropoff);
  if (distance < 30) {
    return error(
      400,
      "points_too_close",
      "Pickup and dropoff need to be at least 30 meters apart.",
    );
  }
  return json({ quote: quoteFare(distance) });
}

async function create(
  request: Request,
  env: Env,
  nowMs: number,
): Promise<Response> {
  const body = await readJson(request);
  if (!isRecord(body)) {
    return error(400, "validation_error", "Body must be a JSON object.");
  }
  const pickup = readPoint(body.pickup, "pickup");
  const dropoff = readPoint(body.dropoff, "dropoff");
  const ride = await createRide(env.DB, {
    riderName: readRiderName(body.riderName),
    pickup,
    dropoff,
    pickupLabel: readLabel(body.pickupLabel, coordinateLabel(pickup.lat, pickup.lng)),
    dropoffLabel: readLabel(
      body.dropoffLabel,
      coordinateLabel(dropoff.lat, dropoff.lng),
    ),
    nowMs,
  });
  return json({ ride }, 201);
}

function forwardToTracker(
  request: Request,
  env: Env,
  rideId: string,
): Promise<Response> {
  const target = new URL(request.url);
  target.searchParams.set("rideId", rideId);
  const stub = env.RIDE_TRACKER.get(env.RIDE_TRACKER.idFromName(rideId));
  return stub.fetch(new Request(target, request));
}

function readLimit(url: URL): number {
  const raw = url.searchParams.get("limit");
  if (raw === null) return 20;
  const parsed = Number(raw);
  if (!Number.isInteger(parsed)) return 20;
  return Math.min(50, Math.max(1, parsed));
}

function readNow(url: URL): number {
  const raw = url.searchParams.get("at");
  if (raw === null || raw === "") return Date.now();
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) return Date.now();
  return parsed;
}

function toErrorResponse(caught: unknown): Response {
  if (caught instanceof RequestError || caught instanceof RideError) {
    return error(caught.status, caught.code, caught.message);
  }
  console.log(
    JSON.stringify({
      msg: "unhandled_error",
      error: caught instanceof Error ? caught.message : "unknown",
    }),
  );
  return error(500, "internal_error", "The ride service hit an unexpected error.");
}
