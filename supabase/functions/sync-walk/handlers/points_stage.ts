import { asRecord, asString, buildBaseSession, epochToIso, json, logSyncWalkStageFailure, toNumber } from "../support/core.ts";
import type { SyncWalkPointRow, SyncWalkStageRequestContext } from "../support/types.ts";
import { runPointsStagePostProcessing } from "./points_stage_post_processing.ts";

function parsePointRows(
  context: SyncWalkStageRequestContext,
  createdEpoch: number,
): { ok: true; rows: SyncWalkPointRow[] } | { ok: false; response: Response } {
  let parsedPoints: unknown[] = [];
  const rawPointsJSON = asString(context.payload.points_json);
  if (rawPointsJSON) {
    try {
      const decoded = JSON.parse(rawPointsJSON);
      if (Array.isArray(decoded)) parsedPoints = decoded;
    } catch {
      logSyncWalkStageFailure(context.requestId, "points", "parse_points_json", "INVALID_POINTS_JSON");
      return { ok: false, response: json({ error: "INVALID_POINTS_JSON" }, 400) };
    }
  }

  const rows = parsedPoints
    .map((raw, index) => {
      const point = asRecord(raw);
      const seqNo = Math.max(0, Math.trunc(toNumber(point.seq_no ?? point.seqNo, index)));
      const lat = toNumber(point.lat, NaN);
      const lng = toNumber(point.lng, NaN);
      const recordedAt = epochToIso(point.recorded_at ?? point.recordedAt, createdEpoch);
      if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
      return {
        walk_session_id: context.walkSessionId,
        seq_no: seqNo,
        lat,
        lng,
        recorded_at: recordedAt,
        created_at: new Date().toISOString(),
      };
    })
    .filter((row): row is SyncWalkPointRow => Boolean(row));

  return { ok: true, rows };
}

export async function handlePointsStage(
  context: SyncWalkStageRequestContext,
): Promise<Response> {
  const { baseSession, createdEpoch, durationSec } = buildBaseSession(context);
  const { error: sessionUpsertError } = await context.userClient
    .from("walk_sessions")
    .upsert(baseSession, { onConflict: "id" });
  if (sessionUpsertError) {
    logSyncWalkStageFailure(context.requestId, "points", "upsert_session", sessionUpsertError.message);
    return json({ error: sessionUpsertError.message }, 500);
  }

  const parsedRows = parsePointRows(context, createdEpoch);
  if (!parsedRows.ok) {
    return parsedRows.response;
  }

  if (parsedRows.rows.length > 0) {
    const { error: pointsError } = await context.userClient
      .from("walk_points")
      .upsert(parsedRows.rows, { onConflict: "walk_session_id,seq_no" });
    if (pointsError) {
      logSyncWalkStageFailure(context.requestId, "points", "upsert_points", pointsError.message);
      return json({ error: pointsError.message }, 500);
    }
  }

  const postProcessing = await runPointsStagePostProcessing({
    ...context,
    createdEpoch,
    durationSec,
    pointRows: parsedRows.rows,
  });

  return json({
    ok: true,
    request_id: context.requestId,
    stage: "points",
    walk_session_id: context.walkSessionId,
    point_count: parsedRows.rows.length,
    idempotency_key: context.idempotencyKey,
    season_score_summary: postProcessing.seasonScoreSummary,
    season_canonical_summary: postProcessing.seasonCanonicalSummary,
    season_pipeline_summary: postProcessing.seasonPipelineSummary,
    weather_replacement_summary: postProcessing.weatherReplacementSummary,
    quest_progress_summary: postProcessing.questProgressSummary,
  });
}
