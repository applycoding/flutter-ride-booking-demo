import { describe, expect, it } from "vitest";
import { FARE, haversineMeters, quoteFare } from "../src/fare";

describe("quoteFare", () => {
  it("applies the minimum fare to a very short hop", () => {
    const quote = quoteFare(40);
    expect(quote.fareCents).toBe(FARE.minimumCents);
    expect(quote.breakdown.minimumApplied).toBe(true);
    expect(quote.currency).toBe("CAD");
    expect(quote.durationSeconds).toBeGreaterThanOrEqual(60);
  });

  it("sums base, distance, time, and the booking fee", () => {
    const quote = quoteFare(5_000);
    expect(quote.breakdown.distanceCents).toBe(475);
    expect(quote.breakdown.timeCents).toBe(225);
    expect(quote.fareCents).toBe(250 + 475 + 225 + 55);
    expect(quote.breakdown.minimumApplied).toBe(false);
    expect(quote.distanceMeters).toBe(5000);
  });
});

describe("haversineMeters", () => {
  it("is zero for the same point and symmetric", () => {
    const harbour = { lat: 48.4234, lng: -123.37 };
    expect(haversineMeters(harbour, harbour)).toBe(0);
    const wharf = { lat: 48.4227, lng: -123.3822 };
    const forward = haversineMeters(harbour, wharf);
    const back = haversineMeters(wharf, harbour);
    expect(forward).toBeCloseTo(back, 6);
    expect(forward).toBeGreaterThan(800);
    expect(forward).toBeLessThan(1_200);
  });
});
