import { buildBaseSession, json, logSyncWalkStageFailure } from "../support/core.ts";
import type { SyncWalkStageRequestContext } from "../support/types.ts";

export async function handleSessionStage(
  context: SyncWalkStageRequestContext,
): Promise<Response> {
  const { baseSession } = buildBaseSession(context);
  const { error } = await context.userClient
    .from("walk_sessions")
    .upsert(baseSession, { onConflict: "id" });
  if (error) {
    logSyncWalkStageFailure(context.requestId, "session", "upsert_session", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return json({
    ok: true,
    stage: "session",
    walk_session_id: context.walkSessionId,
    idempotency_key: context.idempotencyKey,
  });
}
