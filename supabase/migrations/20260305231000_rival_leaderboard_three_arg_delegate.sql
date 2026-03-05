-- #364 final patch: force 3-arg leaderboard RPC to delegate to jsonb compatibility implementation

create or replace function public.rpc_get_rival_leaderboard(
  in_period_type text default 'week',
  in_top_n integer default 50,
  in_now_ts timestamptz default now()
)
returns table (
  period_type text,
  period_start timestamptz,
  period_end timestamptz,
  season_key text,
  rank_position integer,
  user_key text,
  alias_code text,
  avatar_seed text,
  league text,
  effective_league text,
  fallback_applied boolean,
  score_bucket text,
  is_me boolean
)
language sql
security definer
set search_path = public
as $$
  select *
  from public.rpc_get_rival_leaderboard(
    jsonb_build_object(
      'period_type', in_period_type,
      'top_n', in_top_n,
      'now_ts', in_now_ts
    )
  );
$$;
