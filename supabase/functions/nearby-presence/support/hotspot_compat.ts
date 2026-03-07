import type { NearbyPresenceClient } from "./types.ts";

export async function getNearbyHotspotsWithCompatRPC(
  client: NearbyPresenceClient,
  payload: {
    centerLat: number;
    centerLng: number;
    radiusKm: number;
    nowTs: string;
  },
) {
  const latestAttempt = await client.rpc("rpc_get_nearby_hotspots", {
    in_center_lat: payload.centerLat,
    in_center_lng: payload.centerLng,
    in_radius_km: payload.radiusKm,
    in_now_ts: payload.nowTs,
  });
  if (!latestAttempt.error) {
    return {
      data: latestAttempt.data,
      error: null,
      signature: "latest",
      latestError: null,
    };
  }

  const legacyAttempt = await client.rpc("rpc_get_nearby_hotspots", {
    center_lat: payload.centerLat,
    center_lng: payload.centerLng,
    radius_km: payload.radiusKm,
    now_ts: payload.nowTs,
  });
  if (!legacyAttempt.error) {
    return {
      data: legacyAttempt.data,
      error: null,
      signature: "legacy",
      latestError: latestAttempt.error,
    };
  }

  return {
    data: null,
    error: legacyAttempt.error,
    signature: "none",
    latestError: latestAttempt.error,
  };
}
