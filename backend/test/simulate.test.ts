import { describe, expect, it } from "vitest";
import { planSimulation, projectPosition } from "../src/simulate";

const driver = { lat: 48.4289, lng: -123.3671 };
const pickup = { lat: 48.4289, lng: -123.3671 };
const dropoff = { lat: 48.4234, lng: -123.37 };

describe("projectPosition", () => {
  const plan = planSimulation(driver, pickup, dropoff);
  const startedAtMs = 1_700_000_000_000;

  it("uses the minimum pickup leg when the driver is already there", () => {
    expect(plan.toPickupMs).toBe(8_000);
    expect(plan.dwellMs).toBe(4_000);
    expect(plan.tripMs).toBeGreaterThanOrEqual(10_000);
  });

  it("walks through pickup, a short dwell, the trip, and completion", () => {
    const atStart = projectPosition({
      driver,
      pickup,
      dropoff,
      plan,
      startedAtMs,
      nowMs: startedAtMs + 1_000,
    });
    expect(atStart.status).toBe("en_route_pickup");
    expect(atStart.lat).toBeCloseTo(driver.lat, 5);

    const arriving = projectPosition({
      driver,
      pickup,
      dropoff,
      plan,
      startedAtMs,
      nowMs: startedAtMs + plan.toPickupMs + 1_000,
    });
    expect(arriving.status).toBe("arriving");
    expect(arriving.lat).toBeCloseTo(pickup.lat, 5);

    const onTrip = projectPosition({
      driver,
      pickup,
      dropoff,
      plan,
      startedAtMs,
      nowMs: startedAtMs + plan.toPickupMs + plan.dwellMs + 1_000,
    });
    expect(onTrip.status).toBe("on_trip");
    expect(onTrip.progress).toBeGreaterThan(0);
    expect(onTrip.progress).toBeLessThan(1);

    const done = projectPosition({
      driver,
      pickup,
      dropoff,
      plan,
      startedAtMs,
      nowMs: startedAtMs + plan.toPickupMs + plan.dwellMs + plan.tripMs,
    });
    expect(done.status).toBe("completed");
    expect(done.lat).toBeCloseTo(dropoff.lat, 5);
    expect(done.lng).toBeCloseTo(dropoff.lng, 5);
    expect(done.etaSeconds).toBe(0);
  });
});
