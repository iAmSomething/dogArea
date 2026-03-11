import { asRecord, asUUIDOrNull, geohashEncode, json, roundCoord } from "./core.ts";
import { resolveCanonicalIdempotencyKey } from "../../_shared/request_keys.ts";
import type { NearbyPresenceClient, RequestDTO, VisibilitySettingDTO } from "./types.ts";

const resolveVisibilityRequestUserId = (body: RequestDTO): string | null =>
  asUUIDOrNull(body.userId) ?? asUUIDOrNull(body.user_id);

export async function readVisibilitySetting(
  client: NearbyPresenceClient,
  userId: string,
): Promise<{ ok: true; visibility: VisibilitySettingDTO } | { ok: false; response: Response }> {
  const { data: visibility, error } = await client
    .from("user_visibility_settings")
    .select("location_sharing_enabled, updated_at")
    .eq("user_id", userId)
    .maybeSingle();

  if (error) {
    return { ok: false, response: json({ error: error.message }, 500) };
  }

  return {
    ok: true,
    visibility: {
      enabled: Boolean(visibility?.location_sharing_enabled),
      updated_at: visibility?.updated_at ?? null,
    },
  };
}

export async function handleGetVisibility(
  client: NearbyPresenceClient,
  body: RequestDTO,
): Promise<Response> {
  const userId = resolveVisibilityRequestUserId(body);
  if (!userId) {
    return json({ error: "INVALID_PAYLOAD" }, 400);
  }

  const visibility = await readVisibilitySetting(client, userId);
  if (!visibility.ok) {
    return visibility.response;
  }

  return json({
    ok: true,
    request_id: resolveCanonicalIdempotencyKey(asRecord(body), {
      keys: ["request_id", "requestId", "action_id"],
      fallback: null,
    }),
    visibility: visibility.visibility,
  });
}

export async function handleSetVisibility(
  client: NearbyPresenceClient,
  body: RequestDTO,
): Promise<Response> {
  const userId = resolveVisibilityRequestUserId(body);
  if (!userId || typeof body.enabled !== "boolean") {
    return json({ error: "INVALID_PAYLOAD" }, 400);
  }

  const { error } = await client.from("user_visibility_settings").upsert({
    user_id: userId,
    location_sharing_enabled: body.enabled,
    updated_at: new Date().toISOString(),
  });
  if (error) return json({ error: error.message }, 500);

  const visibility = await readVisibilitySetting(client, userId);
  if (!visibility.ok) {
    return visibility.response;
  }

  return json({ ok: true, request_id: resolveCanonicalIdempotencyKey(asRecord(body), {
    keys: ["request_id", "requestId", "action_id"],
    fallback: null,
  }), visibility: visibility.visibility });
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
  if (!visibility.visibility.enabled) {
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

  const bodyRecord = asRecord(body)
  const livePresenceResult = await upsertLivePresence(client, {
    userId,
    sessionId: body.sessionId,
    deviceKey: body.deviceKey,
    latitude: latRounded,
    longitude: lngRounded,
    speedMps: body.speedMps,
    sequence: body.sequence,
    idempotencyKey: resolveCanonicalIdempotencyKey(bodyRecord, {
      keys: ["idempotency_key", "idempotencyKey", "request_id", "requestId", "action_id"],
      fallback: null,
    }) ?? undefined,
    updatedAt: body.updatedAt,
    ttlSeconds: body.ttlSeconds,
  });
  if (livePresenceResult.error) return json({ error: livePresenceResult.error.message }, 500);

  return json({
    ok: true,
    request_id: resolveCanonicalIdempotencyKey(bodyRecord, {
      keys: ["request_id", "requestId", "action_id"],
      fallback: null,
    }),
    geohash7,
    live_presence: livePresenceResult.row,
  });
}
