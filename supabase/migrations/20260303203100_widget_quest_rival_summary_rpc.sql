-- #219 widget quest/rival combined summary rpc

create or replace function public.rpc_get_widget_quest_rival_summary(
  in_now_ts timestamptz default now()
)
returns table (
  quest_instance_id uuid,
  quest_title text,
  quest_progress_value double precision,
  quest_target_value double precision,
  quest_claimable boolean,
  quest_reward_point integer,
  rival_rank integer,
  rival_league text,
  refreshed_at timestamptz,
  has_data boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  requester_uid uuid;
  quest_row record;
  rival_row record;
begin
  requester_uid := auth.uid();
  if requester_uid is null then
    return;
  end if;

  select
    qi.id,
    qi.title_snapshot,
    qi.progress_value,
    qi.target_value_snapshot,
    (qi.status = 'completed' and qi.claimed_at is null) as claimable,
    qi.reward_points_snapshot
  into quest_row
  from public.quest_instances qi
  where qi.owner_user_id = requester_uid
    and qi.status in ('active', 'completed', 'claimed')
    and qi.expires_at >= in_now_ts - interval '1 day'
  order by
    case
      when qi.status = 'completed' and qi.claimed_at is null then 0
      when qi.status = 'active' then 1
      when qi.status = 'claimed' then 2
      else 3
    end,
    qi.updated_at desc
  limit 1;

  select
    r.rank_position,
    r.effective_league
  into rival_row
  from public.rpc_get_rival_leaderboard('week', 50, in_now_ts) r
  where r.is_me = true
  limit 1;

  return query
  select
    quest_row.id::uuid,
    coalesce(quest_row.title_snapshot::text, '오늘의 퀘스트를 준비 중입니다.'),
    coalesce(quest_row.progress_value::double precision, 0::double precision),
    greatest(coalesce(quest_row.target_value_snapshot::double precision, 1::double precision), 1::double precision),
    coalesce(quest_row.claimable::boolean, false),
    greatest(coalesce(quest_row.reward_points_snapshot::integer, 0), 0),
    rival_row.rank_position::integer,
    coalesce(rival_row.effective_league::text, 'onboarding'),
    in_now_ts,
    (quest_row.id is not null or rival_row.rank_position is not null);
end;
$$;

revoke all on function public.rpc_get_widget_quest_rival_summary(timestamptz) from public;
grant execute on function public.rpc_get_widget_quest_rival_summary(timestamptz) to authenticated, service_role;
