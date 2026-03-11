import { json } from "../support/core.ts";
import { upsertLivePresence } from "../support/live_presence.ts";
import { handleGetVisibility, handleSetVisibility, handleUpsertPresence } from "../support/visibility.ts";
import type { Action, NearbyPresenceRequestContext } from "../support/types.ts";
import { handleGetHotspots } from "./hotspot_handler.ts";
import { handleGetLivePresence, handleUpsertLivePresence } from "./live_presence_handlers.ts";

const nearbyPresenceActionHandlers: Record<Action, (context: NearbyPresenceRequestContext) => Promise<Response>> = {
  set_visibility: (context) => handleSetVisibility(context.client, context.body),
  get_visibility: (context) => handleGetVisibility(context.client, context.body),
  upsert_presence: (context) => handleUpsertPresence(context.client, context.body, upsertLivePresence),
  get_hotspots: handleGetHotspots,
  upsert_live_presence: handleUpsertLivePresence,
  get_live_presence: handleGetLivePresence,
};

export const isSupportedNearbyPresenceAction = (value: unknown): value is Action =>
  value === "set_visibility" ||
  value === "get_visibility" ||
  value === "upsert_presence" ||
  value === "get_hotspots" ||
  value === "upsert_live_presence" ||
  value === "get_live_presence";

export async function dispatchNearbyPresenceAction(
  action: Action,
  context: NearbyPresenceRequestContext,
): Promise<Response> {
  const handler = nearbyPresenceActionHandlers[action];
  if (!handler) {
    return json({ error: "UNSUPPORTED_ACTION" }, 400);
  }

  return handler(context);
}
