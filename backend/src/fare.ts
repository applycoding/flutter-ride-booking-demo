export interface LatLng {
  lat: number;
  lng: number;
}

export interface FareBreakdown {
  baseCents: number;
  distanceCents: number;
  timeCents: number;
  bookingCents: number;
  minimumApplied: boolean;
}

export interface FareQuote {
  distanceMeters: number;
  durationSeconds: number;
  fareCents: number;
  currency: "CAD";
  breakdown: FareBreakdown;
}

/** Published demo tariff for Quay. Integers are cents. */
export const FARE = {
  baseCents: 250,
  perKmCents: 95,
  perMinCents: 18,
  bookingCents: 55,
  minimumCents: 500,
  assumeKmh: 24,
} as const;

const EARTH_RADIUS_METERS = 6_371_000;

export function haversineMeters(from: LatLng, to: LatLng): number {
  const lat1 = (from.lat * Math.PI) / 180;
  const lat2 = (to.lat * Math.PI) / 180;
  const dLat = ((to.lat - from.lat) * Math.PI) / 180;
  const dLng = ((to.lng - from.lng) * Math.PI) / 180;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function quoteFare(distanceMeters: number): FareQuote {
  const safeMeters = Math.max(0, distanceMeters);
  const distanceKm = safeMeters / 1000;
  const minutes = (distanceKm / FARE.assumeKmh) * 60;
  const distanceCents = Math.round(distanceKm * FARE.perKmCents);
  const timeCents = Math.round(minutes * FARE.perMinCents);
  const raw =
    FARE.baseCents + distanceCents + timeCents + FARE.bookingCents;
  const minimumApplied = raw < FARE.minimumCents;
  return {
    distanceMeters: Math.round(safeMeters),
    durationSeconds: Math.max(60, Math.round(minutes * 60)),
    fareCents: minimumApplied ? FARE.minimumCents : raw,
    currency: "CAD",
    breakdown: {
      baseCents: FARE.baseCents,
      distanceCents,
      timeCents,
      bookingCents: FARE.bookingCents,
      minimumApplied,
    },
  };
}
