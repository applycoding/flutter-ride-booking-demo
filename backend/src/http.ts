export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET,POST,OPTIONS",
      "access-control-allow-headers": "Content-Type",
      "cache-control": "no-store",
    },
  });
}

export function empty(status = 204): Response {
  return new Response(null, {
    status,
    headers: {
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET,POST,OPTIONS",
      "access-control-allow-headers": "Content-Type",
    },
  });
}

export function error(status: number, code: string, message: string): Response {
  return json({ error: { code, message } }, status);
}

export async function readJson(request: Request): Promise<unknown> {
  const length = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(length) && length > 20_000) {
    throw new RequestError(413, "payload_too_large", "JSON body is too large.");
  }
  try {
    return await request.json();
  } catch {
    throw new RequestError(400, "invalid_json", "Body must be JSON.");
  }
}

export class RequestError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "RequestError";
  }
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function readPoint(
  value: unknown,
  label: string,
): { lat: number; lng: number } {
  if (!isRecord(value)) {
    throw new RequestError(400, "validation_error", `${label} must be an object.`);
  }
  const lat = value.lat;
  const lng = value.lng;
  if (typeof lat !== "number" || typeof lng !== "number") {
    throw new RequestError(
      400,
      "validation_error",
      `${label}.lat and ${label}.lng must be numbers.`,
    );
  }
  if (!Number.isFinite(lat) || lat < -90 || lat > 90) {
    throw new RequestError(400, "validation_error", `${label}.lat is out of range.`);
  }
  if (!Number.isFinite(lng) || lng < -180 || lng > 180) {
    throw new RequestError(400, "validation_error", `${label}.lng is out of range.`);
  }
  return { lat, lng };
}

export function readLabel(value: unknown, fallback: string): string {
  if (value === undefined || value === null) return fallback;
  if (typeof value !== "string") {
    throw new RequestError(400, "validation_error", "Labels must be strings.");
  }
  const trimmed = value.trim();
  if (trimmed.length === 0) return fallback;
  if (trimmed.length > 80) {
    throw new RequestError(400, "validation_error", "Labels must be 80 characters or fewer.");
  }
  return trimmed;
}

export function readRiderName(value: unknown): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new RequestError(400, "validation_error", "riderName is required.");
  }
  const trimmed = value.trim();
  if (trimmed.length > 40) {
    throw new RequestError(
      400,
      "validation_error",
      "riderName must be 40 characters or fewer.",
    );
  }
  return trimmed;
}

export function coordinateLabel(lat: number, lng: number): string {
  return `${lat.toFixed(4)}, ${lng.toFixed(4)}`;
}
