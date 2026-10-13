import { DurableObject } from "cloudflare:workers";
import { error, json } from "./http";
import { RideError, cancelRide, syncRide } from "./rides";

/**
 * One tracker per ride. Position updates for that ride are serialized here,
 * whether they arrive as HTTP polls or as a WebSocket watch.
 */
export class RideTracker extends DurableObject<Env> {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const rideId = url.searchParams.get("rideId");
    if (!rideId) {
      return error(400, "validation_error", "rideId is required.");
    }
    await this.ctx.storage.put("rideId", rideId);
    if (request.headers.get("Upgrade") === "websocket") {
      return this.openSocket(request, rideId);
    }
    if (request.method === "GET") {
      return this.track(rideId, readNow(url));
    }
    if (request.method === "POST" && url.pathname.endsWith("/cancel")) {
      return this.cancel(rideId, readNow(url));
    }
    return error(405, "method_not_allowed", "This tracker route does not support that method.");
  }

  async alarm(): Promise<void> {
    const rideId = await this.ctx.storage.get<string>("rideId");
    const sockets = this.ctx.getWebSockets();
    if (!rideId || sockets.length === 0) return;
    const payload = await this.payload(rideId, Date.now());
    const body = JSON.stringify(payload.body);
    for (const socket of sockets) {
      socket.send(body);
    }
    if (payload.keepWatching) {
      await this.ctx.storage.setAlarm(Date.now() + 1000);
    }
  }

  async webSocketClose(ws: WebSocket): Promise<void> {
    ws.close();
  }

  private async openSocket(request: Request, rideId: string): Promise<Response> {
    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];
    this.ctx.acceptWebSocket(server);
    const payload = await this.payload(rideId, readNow(new URL(request.url)));
    server.send(JSON.stringify(payload.body));
    if (payload.keepWatching) {
      const existing = await this.ctx.storage.getAlarm();
      if (existing === null) {
        await this.ctx.storage.setAlarm(Date.now() + 1000);
      }
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  private async track(rideId: string, nowMs: number): Promise<Response> {
    const payload = await this.payload(rideId, nowMs);
    return json(payload.body, payload.status);
  }

  private async cancel(rideId: string, nowMs: number): Promise<Response> {
    try {
      const ride = await cancelRide(this.env.DB, rideId, nowMs);
      if (!ride) return error(404, "not_found", "No ride with that id.");
      return json({ ride });
    } catch (caught) {
      if (caught instanceof RideError) return error(caught.status, caught.code, caught.message);
      throw caught;
    }
  }

  private async payload(
    rideId: string,
    nowMs: number,
  ): Promise<{ status: number; body: unknown; keepWatching: boolean }> {
    try {
      const track = await syncRide(this.env.DB, rideId, nowMs);
      if (!track) {
        return {
          status: 404,
          body: { error: { code: "not_found", message: "No ride with that id." } },
          keepWatching: false,
        };
      }
      const terminal =
        track.ride.status === "completed" || track.ride.status === "cancelled";
      return { status: 200, body: track, keepWatching: !terminal };
    } catch (caught) {
      if (caught instanceof RideError) {
        return {
          status: caught.status,
          body: { error: { code: caught.code, message: caught.message } },
          keepWatching: false,
        };
      }
      throw caught;
    }
  }
}

function readNow(url: URL): number {
  const raw = url.searchParams.get("at");
  if (raw === null || raw === "") return Date.now();
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) {
    return Date.now();
  }
  return parsed;
}
