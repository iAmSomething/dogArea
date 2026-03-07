import type {
  SyncWalkBaseSessionContext,
  SyncWalkStageRequestContext,
} from "./types.ts";

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

export const asRecord = (value: unknown): Record<string, unknown> =>
  typeof value === "object" && value !== null ? value as Record<string, unknown> : {};

export const asString = (value: unknown): string | null => {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
};

export const toNumber = (value: unknown, fallback = 0): number => {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
};

export const epochToIso = (value: unknown, fallbackEpochSec: number): string => {
  const epoch = toNumber(value, fallbackEpochSec);
  return new Date(Math.max(0, epoch) * 1000).toISOString();
};

export const toUUIDOrNull = (value: unknown): string | null => {
  const raw = asString(value);
  if (!raw) return null;
  const normalized = raw.toLowerCase();
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
  return uuidPattern.test(normalized) ? normalized : null;
};

export const logSyncWalkStageFailure = (
  requestId: string,
  stage: string,
  scope: string,
  detail: string,
) => {
  console.warn("[sync-walk]", {
    request_id: requestId,
    stage,
    scope,
    detail,
  });
};

export const buildBaseSession = (
  context: SyncWalkStageRequestContext,
): SyncWalkBaseSessionContext => {
  const createdEpoch = toNumber(context.payload.created_at, Date.now() / 1000);
  const startedEpoch = toNumber(context.payload.started_at, createdEpoch);
  const endedEpoch = toNumber(context.payload.ended_at, createdEpoch);
  const durationSec = Math.max(
    0,
    Math.round(toNumber(context.payload.duration_sec, Math.max(0, endedEpoch - startedEpoch))),
  );
  const areaM2 = Math.max(0, toNumber(context.payload.area_m2, 0));
  const sourceDevice = asString(context.payload.source_device) ?? "ios";
  const petId = toUUIDOrNull(context.payload.pet_id);

  return {
    baseSession: {
      id: context.walkSessionId,
      owner_user_id: context.userId,
      pet_id: petId,
      started_at: epochToIso(startedEpoch, startedEpoch),
      ended_at: epochToIso(endedEpoch, endedEpoch),
      duration_sec: durationSec,
      area_m2: areaM2,
      source_device: sourceDevice,
      created_at: epochToIso(createdEpoch, createdEpoch),
      updated_at: new Date().toISOString(),
    },
    createdEpoch,
    durationSec,
  };
};
