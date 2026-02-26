import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

type Action = "set_visibility" | "upsert_presence" | "get_hotspots";

type RequestDTO = {
  action: Action;
  userId?: string;
  enabled?: boolean;
  lat?: number;
  lng?: number;
  centerLat?: number;
  centerLng?: number;
  radiusKm?: number;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const roundCoord = (value: number) => Math.round(value * 10_000) / 10_000;

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
    if (!body.userId || typeof body.enabled !== "boolean") {
      return json({ error: "INVALID_PAYLOAD" }, 400);
    }
    const { error } = await client.from("user_visibility_settings").upsert({
      user_id: body.userId,
      location_sharing_enabled: body.enabled,
      updated_at: new Date().toISOString(),
    });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true });
  }

  if (body.action === "upsert_presence") {
    if (!body.userId || typeof body.lat !== "number" || typeof body.lng !== "number") {
      return json({ error: "INVALID_PAYLOAD" }, 400);
    }

    const { data: visibility, error: visibilityError } = await client
      .from("user_visibility_settings")
      .select("location_sharing_enabled")
      .eq("user_id", body.userId)
      .maybeSingle();

    if (visibilityError) return json({ error: visibilityError.message }, 500);
    if (!visibility?.location_sharing_enabled) {
      return json({ ok: true, skipped: "location_sharing_disabled" });
    }

    const latRounded = roundCoord(body.lat);
    const lngRounded = roundCoord(body.lng);
    const geohash7 = geohashEncode(latRounded, lngRounded, 7);

    const { error } = await client.from("nearby_presence").upsert({
      user_id: body.userId,
      geohash7,
      lat_rounded: latRounded,
      lng_rounded: lngRounded,
      last_seen_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true, geohash7 });
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
    return json({ hotspots: data ?? [] });
  }

  return json({ error: "UNSUPPORTED_ACTION" }, 400);
});
