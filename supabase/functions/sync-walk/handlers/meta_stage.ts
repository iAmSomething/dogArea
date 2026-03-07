import { asString, json, logSyncWalkStageFailure } from "../support/core.ts";
import type { SyncWalkStageRequestContext } from "../support/types.ts";

export async function handleMetaStage(
  context: SyncWalkStageRequestContext,
): Promise<Response> {
  const mapImageURL = asString(context.payload.map_image_url);
  const hasImage = asString(context.payload.has_image) === "true";
  const patch: Record<string, unknown> = {
    updated_at: new Date().toISOString(),
  };
  if (hasImage && mapImageURL) {
    patch.map_image_url = mapImageURL;
  }

  const { error } = await context.userClient
    .from("walk_sessions")
    .update(patch)
    .eq("id", context.walkSessionId)
    .eq("owner_user_id", context.userId);
  if (error) {
    logSyncWalkStageFailure(context.requestId, "meta", "update_session_meta", error.message);
    return json({ error: error.message }, 500);
  }

  return json({ ok: true, stage: "meta", walk_session_id: context.walkSessionId });
}
