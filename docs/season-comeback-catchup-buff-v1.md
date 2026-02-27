# Season Comeback Catch-up Buff v1

이 문서는 이슈 #145(시즌 복귀자 캐치업 버프) 구현 기준을 정의한다.

## 1. 목표
- 72시간 이상 비활동 사용자가 복귀했을 때 초기 적응 구간을 보정한다.
- 시즌 점수 악용을 막기 위해 지급 조건/주간 한도/시즌 종료 구간 차단을 함께 적용한다.

## 2. 정책
- 자격: 마지막 활동 종료 시각 기준 `72h` 이상 비활동
- 버프 기간: 지급 시점부터 `48h`
- 보정: 신규 타일 기여 점수에만 `+20%` 적용
- 주간 한도: 사용자당 `1회`
- 시즌 종료 보호: 시즌 종료 `24h` 전부터 신규 버프 지급 금지
- 남용 감지: 최근 28일 grant 횟수 임계(`abuse_grant_count_28d`) 초과 시 `abuse_flag=true`

## 3. 데이터 모델
- `season_catchup_buff_policies`
  - 정책 파라미터(활성/비활성, 임계값, 보정률, 한도)
- `season_catchup_buff_grants`
  - 실제 지급/차단 기록
  - `status`: `active|expired|blocked`
  - `blocked_reason`: `season_end_window|weekly_limit_reached|insufficient_inactivity|no_prior_activity`

## 4. 점수 계산 연결
`rpc_score_walk_session_anti_farming`가 안티 농사 점수 계산과 캐치업 버프 판정을 통합 처리한다.

반환 확장 컬럼:
- `catchup_bonus`
- `catchup_buff_active`
- `catchup_buff_granted_at`
- `catchup_buff_expires_at`
- `explain.catchup_buff.{status, block_reason, weekly_limit, bonus_score, abuse_suspected}`

## 5. iOS UX 반영
- `sync-walk` points stage 응답에서 `season_score_summary`를 파싱한다.
- `SeasonCatchupBuffSnapshot`을 로컬 저장소(UserDefaults)에 보관한다.
- Home 상단 배너에서 상태를 표시한다.
  - 적용 중: `복귀 버프 적용 중(+20%) ...`
  - 차단: 차단 사유(주간 한도/시즌 종료 구간/비활동 시간 미달)
  - 만료: 최근 만료 상태 안내

## 6. 운영/QA 쿼리
지급/차단 기록:
```sql
select
  owner_user_id,
  status,
  blocked_reason,
  granted_at,
  expires_at,
  boost_rate,
  abuse_flag,
  created_at
from public.season_catchup_buff_grants
order by created_at desc
limit 100;
```

14일 KPI:
```sql
select *
from public.view_season_catchup_buff_kpis_14d
order by day_bucket desc;
```
