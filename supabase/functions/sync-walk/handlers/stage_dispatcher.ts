import type { SyncStage, SyncWalkStageRequestContext } from "../support/types.ts";
import { json } from "../support/core.ts";
import { handleMetaStage } from "./meta_stage.ts";
import { handlePointsStage } from "./points_stage.ts";
import { handleSessionStage } from "./session_stage.ts";

const syncWalkStageHandlers: Record<SyncStage, (context: SyncWalkStageRequestContext) => Promise<Response>> = {
  session: handleSessionStage,
  points: handlePointsStage,
  meta: handleMetaStage,
};

export const isSupportedSyncStage = (value: unknown): value is SyncStage =>
  value === "session" || value === "points" || value === "meta";

export async function dispatchSyncWalkStage(
  stage: SyncStage,
  context: SyncWalkStageRequestContext,
): Promise<Response> {
  const handler = syncWalkStageHandlers[stage];
  if (!handler) {
    return json({ error: "UNSUPPORTED_STAGE" }, 400);
  }

  return handler(context);
}
