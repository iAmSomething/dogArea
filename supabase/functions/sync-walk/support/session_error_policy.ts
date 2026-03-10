import { toNumber, toUUIDOrNull } from "./core.ts";
import type { SyncWalkStageRequestContext } from "./types.ts";

type DatabaseErrorLike = {
  code?: string | null;
  message: string;
  details?: string | null;
  hint?: string | null;
};

type SessionStageFailure = {
  status: number;
  retryable: boolean;
  code: string;
  detail: string;
  scope: string;
  body: Record<string, unknown>;
};

const TRANSIENT_POSTGRES_ERROR_CODES = new Set([
  "08000",
  "08001",
  "08003",
  "08006",
  "40001",
  "40P01",
  "53300",
  "53400",
  "57P03",
]);

const makeSessionStageFailure = (
  context: SyncWalkStageRequestContext,
  options: {
    status: number;
    retryable: boolean;
    code: string;
    message: string;
    detail: string;
    scope: string;
  },
): SessionStageFailure => ({
  status: options.status,
  retryable: options.retryable,
  code: options.code,
  detail: options.detail,
  scope: options.scope,
  body: {
    ok: false,
    version: "2026-03-11.v1",
    request_id: context.requestId,
    walk_session_id: context.walkSessionId,
    stage: "session",
    scope: options.scope,
    retryable: options.retryable,
    code: options.code,
    error: options.code,
    message: options.message,
    detail: options.detail,
  },
});

export const validateSessionStagePayload = (
  context: SyncWalkStageRequestContext,
): SessionStageFailure | null => {
  const petId = toUUIDOrNull(context.payload.pet_id);
  if (!petId) {
    return makeSessionStageFailure(context, {
      status: 422,
      retryable: false,
      code: "PET_ID_REQUIRED",
      message: "pet_id is required for session stage.",
      detail: "session payload must include a valid UUID pet_id before walk_sessions upsert.",
      scope: "validate_session_payload",
    });
  }

  const createdEpoch = toNumber(context.payload.created_at, Date.now() / 1000);
  const startedEpoch = toNumber(context.payload.started_at, createdEpoch);
  const endedEpoch = toNumber(context.payload.ended_at, createdEpoch);
  if (endedEpoch < startedEpoch) {
    return makeSessionStageFailure(context, {
      status: 422,
      retryable: false,
      code: "SESSION_TIME_RANGE_INVALID",
      message: "ended_at must be greater than or equal to started_at.",
      detail: `started_at=${startedEpoch} ended_at=${endedEpoch}`,
      scope: "validate_session_payload",
    });
  }

  return null;
};

export const classifySessionStageDatabaseFailure = (
  context: SyncWalkStageRequestContext,
  error: DatabaseErrorLike,
): SessionStageFailure => {
  const detail = [error.message, error.details, error.hint]
    .filter((value): value is string => Boolean(value && value.trim().length > 0))
    .join(" | ");
  const normalized = detail.toLowerCase();
  const code = error.code ?? "";

  if (code === "23502" && normalized.includes("pet_id")) {
    return makeSessionStageFailure(context, {
      status: 422,
      retryable: false,
      code: "PET_ID_REQUIRED",
      message: "pet_id is required for session stage.",
      detail,
      scope: "upsert_session",
    });
  }

  if (code === "23503" && normalized.includes("walk_sessions_pet_id_fkey")) {
    return makeSessionStageFailure(context, {
      status: 422,
      retryable: false,
      code: "SESSION_INVALID_PET_REFERENCE",
      message: "pet_id must reference an existing pet owned by the member.",
      detail,
      scope: "upsert_session",
    });
  }

  if (code === "23514" && normalized.includes("walk_sessions_ended_after_started_check")) {
    return makeSessionStageFailure(context, {
      status: 422,
      retryable: false,
      code: "SESSION_TIME_RANGE_INVALID",
      message: "ended_at must be greater than or equal to started_at.",
      detail,
      scope: "upsert_session",
    });
  }

  if (code === "42501" || normalized.includes("row-level security")) {
    return makeSessionStageFailure(context, {
      status: 409,
      retryable: false,
      code: "SESSION_OWNERSHIP_CONFLICT",
      message: "session owner or pet ownership context is invalid.",
      detail,
      scope: "upsert_session",
    });
  }

  if (code === "23505") {
    return makeSessionStageFailure(context, {
      status: 409,
      retryable: false,
      code: "SESSION_CONFLICT",
      message: "walk session state conflicts with an existing server record.",
      detail,
      scope: "upsert_session",
    });
  }

  if (TRANSIENT_POSTGRES_ERROR_CODES.has(code)) {
    return makeSessionStageFailure(context, {
      status: 503,
      retryable: true,
      code: "SESSION_TRANSIENT_DB_FAILURE",
      message: "temporary database failure while upserting walk session.",
      detail,
      scope: "upsert_session",
    });
  }

  return makeSessionStageFailure(context, {
    status: 500,
    retryable: true,
    code: "SESSION_UNKNOWN_DB_FAILURE",
    message: "unexpected database failure while upserting walk session.",
    detail,
    scope: "upsert_session",
  });
};
