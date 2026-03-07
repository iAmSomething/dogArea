import { asUUIDOrNull, geohashEncode, json, roundCoord } from "./core.ts";
import type { NearbyPresenceClient, RequestDTO } from "./types.ts";

export async function readVisibilitySetting(
  client: NearbyPresenceClient,
  userId: string,
): Promise<{ ok: true; enabled: boolean } | { ok: false; response: Response }> {
  const { data: visibility, error } = await client
    .from("user_visibility_settings")
    .select("location_sharing_enabled")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    return { ok: false, response: json({ error: error.message }, 500) };
  }

  return {
    ok: true,
    enabled: Boolean(visibility?.location_sharing_enabled),
  };
}

export async function handleSetVisibility(
  client: NearbyPresenceClient,
  body: RequestDTO,
): Promise<Response> {
  const userId = asUUIDOrNull(body.userId);
  if (!userId || typeof body.enabled !== "boolean") {
    return json({ error: "INVALID_PAYLOAD" }, 400);
  }

  const { error } = await client.from("user_visibility_settings").upsert({
    user_id: userId,
    location_sharing_enabled: body.enabled,
    updated_at: new Date().toISOString(),
  });
  if (error) return json({ error: error.message }, 500);
  return json({ ok: true });
}

export async function handleUpsertPresence(
  client: NearbyPresenceClient,
  body: RequestDTO,
  upsertLivePresence: (client: NearbyPresenceClient, payload: {
    userId: string;
    sessionId?: string;
    deviceKey?: string;
    latitude: number;
    longitude: number;
    speedMps?: number;
    sequence?: number;
    idempotencyKey?: string;
    updatedAt?: string;
    ttlSeconds?: number;
  }) => Promise<{ geohash7: string; row: unknown; error: { message: string } | null }>,
): Promise<Response> {
  const userId = asUUIDOrNull(body.userId);
  if (!userId || typeof body.lat !== "number" || typeof body.lng !== "number") {
    return json({ error: "INVALID_PAYLOAD" }, 400);
  }

  const visibility = await readVisibilitySetting(client, userId);
  if (!visibility.ok) {
    return visibility.response;
  }
  if (!visibility.enabled) {
    return json({ ok: true, skipped: "location_sharing_disabled" });
  }

  const latRounded = roundCoord(body.lat);
  const lngRounded = roundCoord(body.lng);
  const geohash7 = geohashEncode(latRounded, lngRounded, 7);

  const { error } = await client.from("nearby_presence").upsert({
    user_id: userId,
    geohash7,
    lat_rounded: latRounded,
    lng_rounded: lngRounded,
    last_seen_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  });
  if (error) return json({ error: error.message }, 500);

  const livePresenceResult = await upsertLivePresence(client, {
    userId,
    sessionId: body.sessionId,
    deviceKey: body.deviceKey,
    latitude: latRounded,
    longitude: lngRounded,
    speedMps: body.speedMps,
    sequence: body.sequence,
    idempotencyKey: body.idempotencyKey,
    updatedAt: body.updatedAt,
    ttlSeconds: body.ttlSeconds,
  });
  if (livePresenceResult.error) return json({ error: livePresenceResult.error.message }, 500);

  return json({
    ok: true,
    geohash7,
    live_presence: livePresenceResult.row,
  });
}
