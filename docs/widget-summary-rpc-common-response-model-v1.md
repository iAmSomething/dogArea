# Widget Summary RPC Common Response Model v1

Date: 2026-03-07  
Issue: #429

## 목적

`widget summary` 계열 RPC의 응답 모델을 backend 관점에서 비교하고, 공통 메타 필드 표준안을 정의합니다.

이번 문서는 runtime shape를 즉시 바꾸는 문서가 아닙니다. 현재 앱/위젯 호환성을 깨지 않으면서 어떤 방향으로 정리할지 기준을 고정하는 것이 목적입니다.

대상 RPC:

- `rpc_get_widget_territory_summary`
- `rpc_get_widget_hotspot_summary`
- `rpc_get_widget_quest_rival_summary`

## 현재 inventory

| RPC | 현재 요청 방식 | 현재 응답 핵심 필드 | 현재 meta 성격 필드 | 호출 주체 |
| --- | --- | --- | --- | --- |
| `rpc_get_widget_territory_summary` | positional `now_ts` | `today_tile_count`, `weekly_tile_count`, `defense_scheduled_tile_count`, `score_updated_at` | `has_data`, `refreshed_at` | app/widget member |
| `rpc_get_widget_hotspot_summary` | positional `radius_km`, `now_ts` | `signal_level`, `high_cells`, `medium_cells`, `low_cells`, `delay_minutes`, `privacy_mode`, `suppression_reason`, `guide_copy` | `has_data`, `is_cached`, `server_policy`, `refreshed_at` | app/widget anon/member |
| `rpc_get_widget_quest_rival_summary` | canonical `payload jsonb` compat + positional `in_now_ts` | `quest_*`, `rival_rank`, `rival_league` | `has_data`, `refreshed_at` | app/widget member |

## 현재 차이점

### 1. request contract가 다릅니다

- `quest/rival`만 `payload jsonb` wrapper canonical 경로가 존재합니다.
- `territory`와 `hotspot`은 아직 positional canonical입니다.

### 2. meta field 일관성이 부족합니다

공통으로 이미 존재하는 필드:

- `has_data`
- `refreshed_at`

일부 RPC에만 존재하는 필드:

- `is_cached`
- `server_policy`
- `privacy_mode`
- `suppression_reason`
- `guide_copy`

아직 없는 공통 후보:

- `status`
- `message`
- `version`
- `context`
- `summary_type`

### 3. domain payload와 meta가 top-level에서 섞여 있습니다

현재는 도메인 필드와 상태 필드가 모두 top-level에 있습니다.

예:

- territory: `today_tile_count`와 `has_data`가 같은 레벨
- hotspot: `signal_level`, `privacy_mode`, `is_cached`가 같은 레벨
- quest/rival: `quest_title`, `rival_rank`, `has_data`가 같은 레벨

읽기는 단순하지만, summary family 전체를 통일해서 보기에는 shape 해석 비용이 큽니다.

## 공통 meta 표준안

widget summary RPC family의 canonical target은 아래를 권장합니다.

```json
{
  "summary_type": "territory|hotspot|quest_rival",
  "version": "widget_summary_v1",
  "status": "ok|empty|guest_locked|degraded|cached",
  "message": "optional human-readable operator/debug hint",
  "has_data": true,
  "refreshed_at": "2026-03-07T12:34:56Z",
  "context": {
    "is_cached": false,
    "server_policy": "fresh",
    "privacy_mode": "full"
  },
  "summary": {
    "...domain-specific fields..."
  }
}
```

### 필드 규칙

#### `summary_type`

- 필수
- 값:
  - `territory`
  - `hotspot`
  - `quest_rival`

#### `version`

- 필수
- family-level response schema version
- 초기값: `widget_summary_v1`

#### `status`

- 필수
- 추천 값:
  - `ok`
  - `empty`
  - `guest_locked`
  - `cached`
  - `degraded`

의미:

- `ok`: 정상 집계 완료
- `empty`: 오류는 아니지만 표시할 데이터가 없음
- `guest_locked`: guest/unauthenticated 정책상 축약 응답
- `cached`: 최신 집계가 아니라 캐시 결과
- `degraded`: fallback/partial data 응답

#### `message`

- optional
- UI 문구를 직접 강제하는 필드는 아님
- 운영/debug/compat 설명용 힌트

#### `has_data`

- 필수
- domain payload가 비어 있더라도 응답 자체가 정상일 수 있으므로 유지

#### `refreshed_at`

- 필수
- 서버 집계 기준 시각
- snapshot stale 판정의 기준 필드

#### `context`

- optional object
- 요약 family 공통 메타 확장 슬롯
- 예:
  - `is_cached`
  - `server_policy`
  - `privacy_mode`
  - `suppression_reason`
  - `request_mode`

## domain payload 규칙

domain-specific 데이터는 `summary` 아래로 넣는 것을 canonical target으로 삼습니다.

### territory

```json
{
  "summary": {
    "today_tile_count": 3,
    "weekly_tile_count": 18,
    "defense_scheduled_tile_count": 2,
    "score_updated_at": "..."
  }
}
```

### hotspot

```json
{
  "summary": {
    "signal_level": "medium",
    "high_cells": 0,
    "medium_cells": 3,
    "low_cells": 1,
    "delay_minutes": 15,
    "guide_copy": "...",
    "privacy_mode": "percentile_only",
    "suppression_reason": "k_anon"
  }
}
```

### quest_rival

```json
{
  "summary": {
    "quest_instance_id": "...",
    "quest_title": "...",
    "quest_progress_value": 4,
    "quest_target_value": 6,
    "quest_claimable": false,
    "quest_reward_point": 30,
    "rival_rank": 12,
    "rival_league": "mid"
  }
}
```

## 호환성 영향

현재 앱/위젯 소비 코드는 top-level decode를 전제로 합니다.

영향 파일:

- `TerritoryWidgetSummaryService.ResponseDTO`
- `HotspotWidgetSummaryService.ResponseDTO`
- `QuestRivalWidgetSummaryService.ResponseDTO`

즉시 envelope 전환 시 깨지는 이유:

1. Swift `Decodable`이 현재 top-level key만 읽음
2. widget snapshot sync layer가 domain DTO 생성 시 `hasData`, `refreshedAt`를 현재 위치에서 바로 사용
3. `quest/rival`은 fallback decode까지 있어, 단순 migration만으로는 안전하게 바꾸기 어려움

## rollout 권장안

### Phase 1. 문서/정책 고정

- 이번 이슈 범위
- current shape는 유지
- common target만 문서화

### Phase 2. compat envelope 도입

- `territory` / `hotspot`에 `payload jsonb` wrapper canonical 추가
- 세 RPC 모두 envelope response를 반환하는 새 canonical path 도입
- 기존 top-level shape는 compat path로 유지

### Phase 3. 앱 dual-read

- 앱 서비스가 아래 둘 다 읽도록 전환
  - legacy top-level
  - canonical `summary` envelope

### Phase 4. sunset

- smoke/static check 2회 이상 안정화 후 legacy top-level 계약 sunset 검토

## 즉시 통일 가능한 지점

runtime breaking change 없이 지금도 정렬 가능한 지점:

- `has_data`
- `refreshed_at`
- snake_case 유지
- domain field와 meta field naming rule 문서화

## 후속 작업

- canonical envelope compat 도입은 별도 implementation issue로 분리
- implementation issue: `#459`
- `rpc_get_widget_territory_summary` / `rpc_get_widget_hotspot_summary` wrapper canonical 경로 도입
- 앱 `ResponseDTO`를 dual-read decode로 전환

## 검증 포인트

1. 세 migration/RPC shape 비교가 문서와 일치하는지
2. 앱 소비 DTO가 현재 top-level 가정에 묶여 있는지
3. `has_data` / `refreshed_at` 외 공통 meta 후보가 실제 운영에 의미가 있는지
