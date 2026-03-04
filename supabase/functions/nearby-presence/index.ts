import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type Action =
  | "set_visibility"
  | "upsert_presence"
  | "get_hotspots"
  | "upsert_live_presence"
  | "get_live_presence";

type RequestDTO = {
  action: Action;
  userId?: string;
  enabled?: boolean;
  lat?: number;
  lng?: number;
  speedMps?: number;
  sequence?: number;
  idempotencyKey?: string;
  updatedAt?: string;
  ttlSeconds?: number;
  sessionId?: string;
  centerLat?: number;
  centerLng?: number;
  radiusKm?: number;
  minLat?: number;
  maxLat?: number;
  minLng?: number;
  maxLng?: number;
  maxRows?: number;
  privacyMode?: "public" | "private" | "all";
};

type ResponseHotspotDTO = {
  geohash7: string;
  count: number;
  intensity: number;
  center_lat: number;
  center_lng: number;
  sample_count?: number;
  privacy_mode?: string;
  suppression_reason?: string | null;
  delay_minutes?: number;
  required_min_sample?: number;
};

type ResponseLivePresenceDTO = {
  owner_user_id: string;
  session_id: string;
  lat_rounded: number;
  lng_rounded: number;
  geohash7: string;
  speed_mps?: number | null;
  sequence: number;
  idempotency_key: string;
  updated_at: string;
  expires_at: string;
  write_applied?: boolean;
  privacy_mode?: string;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const roundCoord = (value: number) => Math.round(value * 10_000) / 10_000;

const asUUIDOrNull = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const normalized = value.trim().toLowerCase();
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
  return uuidPattern.test(normalized) ? normalized : null;
};

const asFiniteNumberOrNull = (value: unknown): number | null => {
  if (typeof value !== "number") return null;
  return Number.isFinite(value) ? value : null;
};

const asISO8601OrNull = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) return null;
  return new Date(parsed).toISOString();
};

const asPositiveIntegerOrNull = (value: unknown): number | null => {
  if (typeof value !== "number" || Number.isFinite(value) === false) return null;
  const normalized = Math.floor(value);
  return normalized > 0 ? normalized : null;
};

const asNonEmptyTextOrNull = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
};

const geohashEncode = (lat: number, lng: number, precision = 7): string => {
  const base32 = "0123456789bcdefghjkmnpqrstuvwxyz";
  const bits = [16, 8, 4, 2, 1];
  let latRange: [number, number] = [-90, 90];
  let lngRange: [number, number] = [-180, 180];
  let hash = "";
  let bit = 0;
  let ch = 0;
  let even = true;

  while (hash.length < precision) {
    if (even) {
      const mid = (lngRange[0] + lngRange[1]) / 2;
      if (lng >= mid) {
        ch |= bits[bit];
        lngRange = [mid, lngRange[1]];
      } else {
        lngRange = [lngRange[0], mid];
      }
    } else {
      const mid = (latRange[0] + latRange[1]) / 2;
      if (lat >= mid) {
        ch |= bits[bit];
        latRange = [mid, latRange[1]];
      } else {
        latRange = [latRange[0], mid];
      }
    }
    even = !even;
    if (bit < 4) {
      bit += 1;
    } else {
      hash += base32[ch];
      bit = 0;
      ch = 0;
    }
  }
  return hash;
};

const upsertLivePresence = async (
  client: ReturnType<typeof createClient>,
  payload: {
    userId: string;
    sessionId?: string;
    latitude: number;
    longitude: number;
    speedMps?: number;
    sequence?: number;
    idempotencyKey?: string;
    updatedAt?: string;
    ttlSeconds?: number;
  },
) => {
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
  });

  const rows = ((data ?? []) as ResponseLivePresenceDTO[]);
  const first = rows.length > 0 ? rows[0] : null;
  return {
    geohash7,
    row: first,
    error,
  };
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "METHOD_NOT_ALLOWED" }, 405);

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const serviceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !serviceRole) {
    return json({ error: "SERVER_MISCONFIGURED" }, 500);
  }
  const client = createClient(supabaseURL, serviceRole);

  let body: RequestDTO;
  try {
    body = await req.json();
  } catch {
    return json({ error: "INVALID_JSON" }, 400);
  }

  if (!body.action) return json({ error: "ACTION_REQUIRED" }, 400);

  if (body.action === "set_visibility") {
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

  if (body.action === "upsert_presence") {
    const userId = asUUIDOrNull(body.userId);
    if (!userId || typeof body.lat !== "number" || typeof body.lng !== "number") {
      return json({ error: "INVALID_PAYLOAD" }, 400);
    }

    const { data: visibility, error: visibilityError } = await client
      .from("user_visibility_settings")
      .select("location_sharing_enabled")
      .eq("user_id", userId)
      .maybeSingle();

    if (visibilityError) return json({ error: visibilityError.message }, 500);
    if (!visibility?.location_sharing_enabled) {
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

  if (body.action === "upsert_live_presence") {
    const userId = asUUIDOrNull(body.userId);
    if (!userId || typeof body.lat !== "number" || typeof body.lng !== "number") {
      return json({ error: "INVALID_PAYLOAD" }, 400);
    }

    const { data: visibility, error: visibilityError } = await client
      .from("user_visibility_settings")
      .select("location_sharing_enabled")
      .eq("user_id", userId)
      .maybeSingle();

    if (visibilityError) return json({ error: visibilityError.message }, 500);
    if (!visibility?.location_sharing_enabled) {
      return json({ ok: true, skipped: "location_sharing_disabled" });
    }

    const livePresenceResult = await upsertLivePresence(client, {
      userId,
      sessionId: body.sessionId,
      latitude: body.lat,
      longitude: body.lng,
      speedMps: body.speedMps,
      sequence: body.sequence,
      idempotencyKey: body.idempotencyKey,
      updatedAt: body.updatedAt,
      ttlSeconds: body.ttlSeconds,
    });

    if (livePresenceResult.error) return json({ error: livePresenceResult.error.message }, 500);

    return json({
      ok: true,
      geohash7: livePresenceResult.geohash7,
      live_presence: livePresenceResult.row,
    });
  }

  if (body.action === "get_hotspots") {
    if (typeof body.centerLat !== "number" || typeof body.centerLng !== "number") {
      return json({ error: "INVALID_PAYLOAD" }, 400);
    }

    const radiusKm = typeof body.radiusKm === "number" ? body.radiusKm : 1.0;
    const { data, error } = await client.rpc("rpc_get_nearby_hotspots", {
      center_lat: body.centerLat,
      center_lng: body.centerLng,
      radius_km: radiusKm,
      now_ts: new Date().toISOString(),
    });
    if (error) return json({ error: error.message }, 500);

    const hotspots = (data ?? []) as ResponseHotspotDTO[];
    const suppressedHotspots = hotspots.filter((row) => row.suppression_reason != null);
    const maskedHotspots = suppressedHotspots.filter((row) => row.suppression_reason === "sensitive_mask");
    const kAnonHotspots = suppressedHotspots.filter((row) => row.suppression_reason === "k_anon");
    const delayMinutes = hotspots.find((row) => typeof row.delay_minutes === "number")?.delay_minutes ?? 0;
    const alertLevel = suppressedHotspots.length == 0
      ? "info"
      : suppressedHotspots.length >= hotspots.length && hotspots.length > 0
      ? "critical"
      : "warn";

    const requestUserId = asUUIDOrNull(body.userId);
    const { error: auditError } = await client.from("privacy_guard_audit_logs").insert({
      policy_key: "nearby_hotspot",
      request_action: "get_hotspots",
      request_user_id: requestUserId,
      center_lat: body.centerLat,
      center_lng: body.centerLng,
      radius_km: radiusKm,
      total_hotspots: hotspots.length,
      suppressed_hotspots: suppressedHotspots.length,
      masked_hotspots: maskedHotspots.length,
      k_anon_hotspots: kAnonHotspots.length,
      delay_minutes: delayMinutes,
      alert_level: alertLevel,
      payload: {
        required_min_sample: hotspots.find((row) => typeof row.required_min_sample === "number")?.required_min_sample ?? null,
        returned_modes: Array.from(new Set(hotspots.map((row) => row.privacy_mode).filter(Boolean))),
      },
    });

    if (auditError) {
      console.error("privacy audit insert failed", auditError.message);
    }

    return json({ hotspots });
  }

  if (body.action === "get_live_presence") {
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
    const nowTs = new Date().toISOString();

    const { data, error } = await client.rpc("rpc_get_walk_live_presence", {
      in_min_lat: body.minLat,
      in_max_lat: body.maxLat,
      in_min_lng: body.minLng,
      in_max_lng: body.maxLng,
      in_max_rows: maxRows,
      in_privacy_mode: normalizedPrivacyMode,
      in_now_ts: nowTs,
    });
    if (error) return json({ error: error.message }, 500);

    return json({ presence: (data ?? []) as ResponseLivePresenceDTO[] });
  }

  return json({ error: "UNSUPPORTED_ACTION" }, 400);
});
