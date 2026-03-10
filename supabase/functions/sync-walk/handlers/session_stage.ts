import { buildBaseSession, json, logSyncWalkStageFailure } from "../support/core.ts";
import {
  classifySessionStageDatabaseFailure,
  validateSessionStagePayload,
} from "../support/session_error_policy.ts";
import type { SyncWalkStageRequestContext } from "../support/types.ts";

export async function handleSessionStage(
  context: SyncWalkStageRequestContext,
): Promise<Response> {
  const validationFailure = validateSessionStagePayload(context);
  if (validationFailure) {
    logSyncWalkStageFailure(
      context.requestId,
      "session",
      validationFailure.scope,
      validationFailure.detail,
      {
        walk_session_id: context.walkSessionId,
        error_code: validationFailure.code,
        retryable: validationFailure.retryable,
      },
    );
    return json(validationFailure.body, validationFailure.status);
  }

  const { baseSession } = buildBaseSession(context);
  const { error } = await context.userClient
    .from("walk_sessions")
    .upsert(baseSession, { onConflict: "id" });
  if (error) {
    const failure = classifySessionStageDatabaseFailure(context, error);
    logSyncWalkStageFailure(
      context.requestId,
      "session",
      failure.scope,
      failure.detail,
      {
        walk_session_id: context.walkSessionId,
        error_code: failure.code,
        retryable: failure.retryable,
        postgres_code: error.code ?? null,
      },
    );
    return json(failure.body, failure.status);
  }

  return json({
    ok: true,
    request_id: context.requestId,
    stage: "session",
    walk_session_id: context.walkSessionId,
    idempotency_key: context.idempotencyKey,
  });
}
