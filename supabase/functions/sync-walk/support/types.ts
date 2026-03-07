import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.4";

export type SyncStage = "session" | "points" | "meta";
export type Action = "sync_walk_stage" | "get_backfill_summary";

export type RequestDTO = {
  action?: Action;
  stage?: SyncStage;
  walk_session_id?: string;
  idempotency_key?: string;
  payload?: Record<string, unknown>;
  session_ids?: string[];
};

export type SeasonScoreSummaryDTO = {
  walk_session_id: string;
  total_points: number;
  unique_tiles: number;
  novelty_ratio: number;
  repeat_suppressed_count: number;
  suspicious_repeat_count: number;
  base_score: number;
  new_route_bonus: number;
  catchup_bonus?: number;
  total_score: number;
  score_blocked: boolean;
  catchup_buff_active?: boolean;
  catchup_buff_granted_at?: string | null;
  catchup_buff_expires_at?: string | null;
  explain?: Record<string, unknown>;
};

export type WeatherReplacementSummaryDTO = {
  applied: boolean;
  shield_applied: boolean;
  blocked_reason: string | null;
  risk_level: string | null;
  replacement_reason: string | null;
  replacement_count_today: number;
  daily_replacement_limit: number;
  shield_used_this_week: number;
  weekly_shield_limit: number;
};

export type SeasonPipelineSummaryDTO = {
  season_id: string;
  season_key: string;
  ingested_rows: number;
  tile_rows: number;
  user_total_score: number;
  user_rank: number | null;
  run_status: string;
};

export type QuestProgressSummaryDTO = {
  quest_instance_id: string;
  owner_user_id: string;
  event_id: string;
  idempotent: boolean;
  previous_progress: number;
  current_progress: number;
  target_progress: number;
  status: string;
  completed_at: string | null;
};

export type SyncWalkUserClient = ReturnType<typeof createClient>;

export type SyncWalkStageRequestContext = {
  userClient: SyncWalkUserClient;
  userId: string;
  requestId: string;
  walkSessionId: string;
  idempotencyKey: string | null;
  payload: Record<string, unknown>;
};

export type BackfillSummaryRequestContext = {
  userClient: SyncWalkUserClient;
  requestId: string;
  sessionIds: string[];
};

export type SyncWalkBaseSessionRecord = {
  id: string;
  owner_user_id: string;
  pet_id: string | null;
  started_at: string;
  ended_at: string;
  duration_sec: number;
  area_m2: number;
  source_device: string;
  created_at: string;
  updated_at: string;
};

export type SyncWalkBaseSessionContext = {
  baseSession: SyncWalkBaseSessionRecord;
  createdEpoch: number;
  durationSec: number;
};

export type SyncWalkPointRow = {
  walk_session_id: string;
  seq_no: number;
  lat: number;
  lng: number;
  recorded_at: string;
  created_at: string;
};
