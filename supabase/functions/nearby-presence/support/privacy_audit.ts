import type { NearbyPresenceClient, ResponseHotspotDTO, ResponseLivePresenceDTO } from "./types.ts";

export function summarizeHotspotSuppression(hotspots: ResponseHotspotDTO[]) {
  const suppressedHotspots = hotspots.filter((row) => row.suppression_reason != null);
  const maskedHotspots = suppressedHotspots.filter((row) => row.suppression_reason === "sensitive_mask");
  const kAnonHotspots = suppressedHotspots.filter((row) => row.suppression_reason === "k_anon");
  const delayMinutes = hotspots.find((row) => typeof row.delay_minutes === "number")?.delay_minutes ?? 0;
  const alertLevel = suppressedHotspots.length == 0
    ? "info"
    : suppressedHotspots.length >= hotspots.length && hotspots.length > 0
    ? "critical"
    : "warn";

  return {
    suppressedHotspots,
    maskedHotspots,
    kAnonHotspots,
    delayMinutes,
    alertLevel,
  };
}

export async function insertHotspotPrivacyAuditLog(
  client: NearbyPresenceClient,
  payload: {
    requestUserId: string | null;
    centerLat: number;
    centerLng: number;
    radiusKm: number;
    hotspots: ResponseHotspotDTO[];
  },
) {
  const summary = summarizeHotspotSuppression(payload.hotspots);
  const { error } = await client.from("privacy_guard_audit_logs").insert({
    policy_key: "nearby_hotspot",
    request_action: "get_hotspots",
    request_user_id: payload.requestUserId,
    center_lat: payload.centerLat,
    center_lng: payload.centerLng,
    radius_km: payload.radiusKm,
    total_hotspots: payload.hotspots.length,
    suppressed_hotspots: summary.suppressedHotspots.length,
    masked_hotspots: summary.maskedHotspots.length,
    k_anon_hotspots: summary.kAnonHotspots.length,
    delay_minutes: summary.delayMinutes,
    alert_level: summary.alertLevel,
    payload: {
      required_min_sample: payload.hotspots.find((row) => typeof row.required_min_sample === "number")?.required_min_sample ?? null,
      returned_modes: Array.from(new Set(payload.hotspots.map((row) => row.privacy_mode).filter(Boolean))),
    },
  });

  return {
    error,
    summary,
  };
}

export async function insertLivePresencePrivacyAuditLog(
  client: NearbyPresenceClient,
  payload: {
    requestUserId: string | null;
    minLat: number;
    maxLat: number;
    minLng: number;
    maxLng: number;
    maxRows: number;
    privacyMode: string;
    excludedUserIds: string[];
    presence: ResponseLivePresenceDTO[];
  },
) {
  const suppressedCount = payload.presence.filter((row) => row.suppression_reason != null).length;
  const delayedCount = payload.presence.filter((row) => row.suppression_reason === "delayed").length;
  const sensitiveCount = payload.presence.filter((row) => row.suppression_reason === "sensitive_mask").length;
  const kAnonCount = payload.presence.filter((row) => row.suppression_reason === "k_anon").length;
  const excludedCount = payload.excludedUserIds.length;
  const obfuscationMeters = payload.presence.reduce((max, row) => {
    const value = typeof row.obfuscation_meters === "number" ? row.obfuscation_meters : 0;
    return Math.max(max, value);
  }, 0);

  const { error } = await client.from("privacy_guard_audit_logs").insert({
    policy_key: "walk_live_presence",
    request_action: "get_live_presence",
    request_user_id: payload.requestUserId,
    request_min_lat: payload.minLat,
    request_max_lat: payload.maxLat,
    request_min_lng: payload.minLng,
    request_max_lng: payload.maxLng,
    total_presence: payload.presence.length,
    suppressed_presence: suppressedCount,
    delayed_presence: delayedCount,
    sensitive_presence: sensitiveCount,
    k_anon_presence: kAnonCount,
    excluded_presence: excludedCount,
    obfuscation_meters: obfuscationMeters,
    delay_minutes: payload.presence.find((row) => typeof row.delay_minutes === "number")?.delay_minutes ?? 0,
    alert_level: "info",
    payload: {
      requested_max_rows: payload.maxRows,
      privacy_mode: payload.privacyMode,
    },
  });

  return {
    error,
    summary: {
      suppressedCount,
      delayedCount,
      sensitiveCount,
      kAnonCount,
      excludedCount,
      obfuscationMeters,
    },
  };
}
