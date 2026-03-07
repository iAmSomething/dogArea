import { asString, json, logSyncWalkStageFailure, toNumber } from "../support/core.ts";
import type { BackfillSummaryRequestContext } from "../support/types.ts";

export async function handleBackfillSummary(
  context: BackfillSummaryRequestContext,
): Promise<Response> {
  let sessionsQuery = context.userClient
    .from("walk_sessions")
    .select("id,area_m2,duration_sec")
    .order("started_at", { ascending: false });

  if (context.sessionIds.length > 0) {
    sessionsQuery = sessionsQuery.in("id", context.sessionIds);
  }

  const { data: sessions, error: sessionError } = await sessionsQuery;
  if (sessionError) {
    logSyncWalkStageFailure(context.requestId, "get_backfill_summary", "load_sessions", sessionError.message);
    return json({ error: sessionError.message }, 500);
  }

  const safeSessions = sessions ?? [];
  const sessionIds = safeSessions
    .map((row: Record<string, unknown>) => asString(row.id))
    .filter((id: string | null): id is string => Boolean(id));

  let pointCount = 0;
  if (sessionIds.length > 0) {
    const { count, error: pointError } = await context.userClient
      .from("walk_points")
      .select("id", { count: "exact", head: true })
      .in("walk_session_id", sessionIds);
    if (pointError) {
      logSyncWalkStageFailure(context.requestId, "get_backfill_summary", "count_points", pointError.message);
      return json({ error: pointError.message }, 500);
    }
    pointCount = count ?? 0;
  }

  const totalArea = safeSessions.reduce(
    (acc: number, row: Record<string, unknown>) => acc + Math.max(0, toNumber(row.area_m2, 0)),
    0,
  );
  const totalDuration = safeSessions.reduce(
    (acc: number, row: Record<string, unknown>) => acc + Math.max(0, toNumber(row.duration_sec, 0)),
    0,
  );

  return json({
    summary: {
      session_count: safeSessions.length,
      point_count: pointCount,
      total_area_m2: totalArea,
      total_duration_sec: totalDuration,
    },
  });
}
