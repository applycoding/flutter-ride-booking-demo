import { env } from "cloudflare:workers";
import { exports } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import { matchRoute } from "../src/index";

const base = "http://quay.test";

describe("matchRoute", () => {
  it("recognizes the public routes", () => {
    expect(matchRoute("GET", "/health").kind).toBe("health");
    expect(matchRoute("POST", "/v1/fares/estimate").kind).toBe("estimate");
    expect(matchRoute("GET", "/v1/nope").kind).toBe("not_found");
    const track = matchRoute("GET", "/v1/rides/abc/track");
    expect(track).toEqual({ kind: "track", id: "abc" });
  });
});

describe("quay rides api", () => {
  beforeEach(async () => {
    await env.DB.prepare("DELETE FROM rides").run();
    await env.DB.prepare(
      `UPDATE drivers SET status = 'available',
        lat = CASE id
          WHEN 'drv_lila' THEN 48.42890
          WHEN 'drv_omar' THEN 48.41820
          WHEN 'drv_june' THEN 48.42640
          ELSE 48.41480
        END,
        lng = CASE id
          WHEN 'drv_lila' THEN -123.36710
          WHEN 'drv_omar' THEN -123.37840
          WHEN 'drv_june' THEN -123.35890
          ELSE -123.36920
        END`,
    ).run();
  });

  it("reports health and lists the seeded drivers", async () => {
    const health = await exports.default.fetch(`${base}/health`);
    expect(health.status).toBe(200);
    expect(await health.json()).toEqual({ ok: true, service: "quay-rides" });

    const drivers = await exports.default.fetch(`${base}/v1/drivers`);
    const body = (await drivers.json()) as { drivers: { name: string }[] };
    expect(body.drivers.map((driver) => driver.name).sort()).toEqual([
      "June Pell",
      "Lila Ferris",
      "Nico Adler",
      "Omar Vale",
    ]);
  });

  it("quotes a fare and rejects pins that sit on top of each other", async () => {
    const same = await exports.default.fetch(`${base}/v1/fares/estimate`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        pickup: { lat: 48.42, lng: -123.37 },
        dropoff: { lat: 48.42, lng: -123.37 },
      }),
    });
    expect(same.status).toBe(400);

    const quote = await exports.default.fetch(`${base}/v1/fares/estimate`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        pickup: { lat: 48.4234, lng: -123.3706 },
        dropoff: { lat: 48.4194, lng: -123.3702 },
      }),
    });
    expect(quote.status).toBe(200);
    const body = (await quote.json()) as { quote: { fareCents: number } };
    expect(body.quote.fareCents).toBeGreaterThanOrEqual(500);
  });

  it("assigns the nearest driver and moves them through the sped-up trip", async () => {
    const created = await requestRide({
      pickup: { lat: 48.4289, lng: -123.3671 },
      dropoff: { lat: 48.4234, lng: -123.37 },
      riderName: "Alex Marin",
    });
    expect(created.status).toBe(201);
    const ride = created.ride;
    expect(ride.driverId).toBe("drv_lila");
    expect(ride.status).toBe("en_route_pickup");
    expect(ride.playback.toPickupMs).toBe(8_000);

    const started = Date.parse(ride.startedAt);
    const early = await track(ride.id, started + 1_000);
    expect(early.ride.status).toBe("en_route_pickup");
    expect(early.driver.id).toBe("drv_lila");
    expect(early.driver.lat).toBeCloseTo(48.4289, 3);

    const moving = await track(
      ride.id,
      started + ride.playback.toPickupMs + ride.playback.dwellMs + 1_000,
    );
    expect(moving.ride.status).toBe("on_trip");
    expect(moving.progress).toBeGreaterThan(0);
    expect(moving.progress).toBeLessThan(1);

    const done = await track(
      ride.id,
      started +
        ride.playback.toPickupMs +
        ride.playback.dwellMs +
        ride.playback.tripMs,
    );
    expect(done.ride.status).toBe("completed");
    expect(done.driver.status).toBe("available");
    expect(done.driver.lat).toBeCloseTo(48.4234, 3);

    const history = await exports.default.fetch(`${base}/v1/rides`);
    const listed = (await history.json()) as { rides: { id: string; status: string }[] };
    expect(listed.rides[0]?.id).toBe(ride.id);
    expect(listed.rides[0]?.status).toBe("completed");
  });

  it("keeps a busy driver from taking a second ride and frees them on cancel", async () => {
    const first = await requestRide({
      pickup: { lat: 48.4289, lng: -123.3671 },
      dropoff: { lat: 48.4234, lng: -123.37 },
      riderName: "Alex Marin",
    });
    const second = await requestRide({
      pickup: { lat: 48.4289, lng: -123.3671 },
      dropoff: { lat: 48.422, lng: -123.371 },
      riderName: "Sam Ibarra",
    });
    expect(second.ride.driverId).not.toBe(first.ride.driverId);

    const started = Date.parse(first.ride.startedAt);
    const cancelled = await exports.default.fetch(
      `${base}/v1/rides/${first.ride.id}/cancel?at=${started + 1_000}`,
      { method: "POST" },
    );
    expect(cancelled.status).toBe(200);
    const body = (await cancelled.json()) as { ride: { status: string } };
    expect(body.ride.status).toBe("cancelled");

    const drivers = await exports.default.fetch(`${base}/v1/drivers`);
    const roster = (await drivers.json()) as {
      drivers: { id: string; status: string }[];
    };
    expect(roster.drivers.find((driver) => driver.id === "drv_lila")?.status).toBe(
      "available",
    );
  });

  it("rejects a cancel once the simulated trip has started", async () => {
    const created = await requestRide({
      pickup: { lat: 48.4289, lng: -123.3671 },
      dropoff: { lat: 48.4234, lng: -123.37 },
      riderName: "Alex Marin",
    });
    const started = Date.parse(created.ride.startedAt);
    const at =
      started +
      created.ride.playback.toPickupMs +
      created.ride.playback.dwellMs +
      1_000;
    const cancelled = await exports.default.fetch(
      `${base}/v1/rides/${created.ride.id}/cancel?at=${at}`,
      { method: "POST" },
    );
    expect(cancelled.status).toBe(409);
  });

  it("answers a websocket watch with the current track", async () => {
    const created = await requestRide({
      pickup: { lat: 48.4289, lng: -123.3671 },
      dropoff: { lat: 48.4234, lng: -123.37 },
      riderName: "Alex Marin",
    });
    const response = await exports.default.fetch(
      `${base}/v1/rides/${created.ride.id}/watch`,
      { headers: { Upgrade: "websocket" } },
    );
    expect(response.status).toBe(101);
    const socket = response.webSocket;
    expect(socket).toBeTruthy();
    if (!socket) return;
    socket.accept();
    const message = await new Promise<string>((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("watch timed out")), 2_000);
      socket.addEventListener("message", (event) => {
        clearTimeout(timer);
        resolve(String(event.data));
      });
    });
    const body = JSON.parse(message) as { ride: { id: string }; simulated: boolean };
    expect(body.ride.id).toBe(created.ride.id);
    expect(body.simulated).toBe(true);
    socket.close();
  });
});

interface CreatedRide {
  status: number;
  ride: {
    id: string;
    status: string;
    driverId: string;
    startedAt: string;
    playback: { toPickupMs: number; dwellMs: number; tripMs: number };
  };
}

async function requestRide(input: {
  pickup: { lat: number; lng: number };
  dropoff: { lat: number; lng: number };
  riderName: string;
}): Promise<CreatedRide> {
  const response = await exports.default.fetch(`${base}/v1/rides`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      ...input,
      pickupLabel: "Inner Harbour",
      dropoffLabel: "Legislature",
    }),
  });
  const body = (await response.json()) as { ride: CreatedRide["ride"] };
  return { status: response.status, ride: body.ride };
}

async function track(id: string, at: number) {
  const response = await exports.default.fetch(`${base}/v1/rides/${id}/track?at=${at}`);
  expect(response.status).toBe(200);
  return (await response.json()) as {
    ride: { status: string };
    driver: { id: string; lat: number; status: string };
    progress: number;
  };
}
