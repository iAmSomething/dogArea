import { asPositiveIntegerOrNull, asRecord, asUUIDArray, asUUIDOrNull, json } from "../support/core.ts";
import { resolveCanonicalIdempotencyKey } from "../../_shared/request_keys.ts";
import { insertLivePresencePrivacyAuditLog } from "../support/privacy_audit.ts";
import { upsertLivePresence } from "../support/live_presence.ts";
import { readVisibilitySetting } from "../support/visibility.ts";
import type { NearbyPresenceRequestContext, ResponseLivePresenceDTO } from "../support/types.ts";

export async function handleUpsertLivePresence(
  context: NearbyPresenceRequestContext,
): Promise<Response> {
  const userId = asUUIDOrNull(context.body.userId);
  if (!userId || typeof context.body.lat !== "number" || typeof context.body.lng !== "number") {
    return json({ error: "INVALID_PAYLOAD" }, 400);
  }

  const visibility = await readVisibilitySetting(context.client, userId);
  if (!visibility.ok) {
    return visibility.response;
  }
  if (!visibility.enabled) {
    return json({ ok: true, skipped: "location_sharing_disabled" });
  }

  const bodyRecord = asRecord(context.body)
  const livePresenceResult = await upsertLivePresence(context.client, {
    userId,
    sessionId: context.body.sessionId,
    deviceKey: context.body.deviceKey,
    latitude: context.body.lat,
    longitude: context.body.lng,
    speedMps: context.body.speedMps,
    sequence: context.body.sequence,
    idempotencyKey: resolveCanonicalIdempotencyKey(bodyRecord, {
      keys: ["idempotency_key", "idempotencyKey", "request_id", "requestId", "action_id"],
      fallback: context.requestId,
    }) ?? undefined,
    updatedAt: context.body.updatedAt,
    ttlSeconds: context.body.ttlSeconds,
  });

  if (livePresenceResult.error) return json({ error: livePresenceResult.error.message }, 500);

  return json({
    ok: true,
    request_id: context.requestId,
    geohash7: livePresenceResult.geohash7,
    idempotency_key: resolveCanonicalIdempotencyKey(bodyRecord, {
      keys: ["idempotency_key", "idempotencyKey", "request_id", "requestId", "action_id"],
      fallback: context.requestId,
    }),
    live_presence: livePresenceResult.row,
  });
}

export async function handleGetLivePresence(
  context: NearbyPresenceRequestContext,
): Promise<Response> {
  const body = context.body;
  if (
    typeof body.minLat !== "number" ||
    typeof body.maxLat !== "number" ||
    typeof body.minLng !== "number" ||
    typeof body.maxLng !== "number"
  ) {
    return json({ error: "INVALID_PAYLOAD" }, 400);
  }

  const maxRows = Math.max(1, Math.min(asPositiveIntegerOrNull(body.maxRows) ?? 200, 1000));
  const normalizedPrivacyMode = body.privacyMode === "all" || body.privacyMode === "private"
    ? body.privacyMode
    : "public";
  const requestUserId = asUUIDOrNull(body.userId);
  const excludedUserIds = asUUIDArray(body.excludedUserIds);
  const nowTs = new Date().toISOString();

  const { data, error } = await context.client.rpc("rpc_get_walk_live_presence", {
    in_min_lat: body.minLat,
    in_max_lat: body.maxLat,
    in_min_lng: body.minLng,
    in_max_lng: body.maxLng,
    in_max_rows: maxRows,
    in_privacy_mode: normalizedPrivacyMode,
    in_now_ts: nowTs,
    in_request_user_id: requestUserId,
    in_excluded_user_ids: excludedUserIds,
  });
  if (error) return json({ error: error.message }, 500);

  const presence = (data ?? []) as ResponseLivePresenceDTO[];
  const audit = await insertLivePresencePrivacyAuditLog(context.client, {
    requestUserId,
    minLat: body.minLat,
    maxLat: body.maxLat,
    minLng: body.minLng,
    maxLng: body.maxLng,
    maxRows,
    privacyMode: normalizedPrivacyMode,
    excludedUserIds,
    presence,
  });

  if (audit.error) {
    console.error("privacy live audit insert failed", audit.error.message);
  }

  return json({ request_id: context.requestId, presence });
}
