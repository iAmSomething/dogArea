import { asFiniteNumberOrNull, asISO8601OrNull, asNonEmptyTextOrNull, asPositiveIntegerOrNull, asUUIDOrNull, geohashEncode, roundCoord } from "./core.ts";
import type { LivePresenceUpsertPayload, NearbyPresenceClient, ResponseLivePresenceDTO } from "./types.ts";

export async function upsertLivePresence(
  client: NearbyPresenceClient,
  payload: LivePresenceUpsertPayload,
) {
  const latRounded = roundCoord(payload.latitude);
  const lngRounded = roundCoord(payload.longitude);
  const normalizedSessionId = asUUIDOrNull(payload.sessionId) ?? payload.userId;
  const normalizedSequence = asPositiveIntegerOrNull(payload.sequence) ?? 0;
  const normalizedIdempotencyKey = asNonEmptyTextOrNull(payload.idempotencyKey) ??
    `${payload.userId}:${normalizedSequence}:${Date.now()}`;
  const normalizedUpdatedAt = asISO8601OrNull(payload.updatedAt) ?? new Date().toISOString();
  const normalizedTtlSeconds = Math.min(
    90,
    Math.max(60, asPositiveIntegerOrNull(payload.ttlSeconds) ?? 90),
  );
  const normalizedDeviceKey = asNonEmptyTextOrNull(payload.deviceKey);
  const geohash7 = geohashEncode(latRounded, lngRounded, 7);

  const { data, error } = await client.rpc("rpc_upsert_walk_live_presence", {
    in_owner_user_id: payload.userId,
    in_session_id: normalizedSessionId,
    in_lat_rounded: latRounded,
    in_lng_rounded: lngRounded,
    in_geohash7: geohash7,
    in_speed_mps: asFiniteNumberOrNull(payload.speedMps),
    in_sequence: normalizedSequence,
    in_idempotency_key: normalizedIdempotencyKey,
    in_updated_at: normalizedUpdatedAt,
    in_ttl_seconds: normalizedTtlSeconds,
    in_device_key: normalizedDeviceKey,
  });

  const rows = ((data ?? []) as ResponseLivePresenceDTO[]);
  return {
    geohash7,
    row: rows.length > 0 ? rows[0] : null,
    error,
  };
}
