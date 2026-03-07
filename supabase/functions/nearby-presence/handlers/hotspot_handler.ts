import { asUUIDOrNull, json } from "../support/core.ts";
import { getNearbyHotspotsWithCompatRPC } from "../support/hotspot_compat.ts";
import { insertHotspotPrivacyAuditLog } from "../support/privacy_audit.ts";
import type { NearbyPresenceRequestContext, ResponseHotspotDTO } from "../support/types.ts";

export async function handleGetHotspots(
  context: NearbyPresenceRequestContext,
): Promise<Response> {
  const body = context.body;
  if (typeof body.centerLat !== "number" || typeof body.centerLng !== "number") {
    return json({ error: "INVALID_PAYLOAD" }, 400);
  }

  const radiusKm = typeof body.radiusKm === "number" ? body.radiusKm : 1.0;
  const rpcResult = await getNearbyHotspotsWithCompatRPC(context.client, {
    centerLat: body.centerLat,
    centerLng: body.centerLng,
    radiusKm,
    nowTs: new Date().toISOString(),
  });
  if (rpcResult.error) {
    console.error("nearby hotspot rpc failed", {
      centerLat: body.centerLat,
      centerLng: body.centerLng,
      radiusKm,
      latestError: rpcResult.latestError,
      fallbackError: rpcResult.error,
    });
    return json({
      error: rpcResult.error.message,
      code: rpcResult.error.code ?? null,
    }, 500);
  }

  const hotspots = (rpcResult.data ?? []) as ResponseHotspotDTO[];
  const requestUserId = asUUIDOrNull(body.userId);
  const audit = await insertHotspotPrivacyAuditLog(context.client, {
    requestUserId,
    centerLat: body.centerLat,
    centerLng: body.centerLng,
    radiusKm,
    hotspots,
  });

  if (audit.error) {
    console.error("privacy audit insert failed", audit.error.message);
  }

  return json({ request_id: context.requestId, hotspots });
}
