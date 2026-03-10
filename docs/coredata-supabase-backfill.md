# CoreData -> Supabase Backfill Contract v1

## 1. 목적
- CoreData 산책 기록을 Supabase로 점진 이관한다.
- 이관은 `session -> points -> meta` 3단계 outbox로 처리한다.
- 재실행해도 중복이 늘어나지 않는 멱등(idempotent) 이관을 보장한다.

## 2. 입력 DTO 계약
`CoreDataSupabaseBackfillDTOConverter`는 `Polygon`/`PolygonEntity`를 아래 DTO로 변환한다.

- `WalkSessionBackfillDTO`
  - `walkSessionId` (UUID 문자열)
  - `ownerUserId` (로그/추적용)
  - `petId` (UUID 문자열, 없으면 null)
  - `createdAt` / `startedAt` / `endedAt` (epoch seconds)
  - `durationSec`, `areaM2`
  - `sourceDevice`
  - `hasImage`, `mapImageURL`
  - `points: [WalkPointBackfillDTO]`
- `WalkPointBackfillDTO`
  - `seqNo`, `lat`, `lng`, `recordedAt`

## 3. Outbox stage payload
### 3.1 session stage
필수 payload 키:
- `walk_session_id`
- `created_at`
- `started_at`
- `ended_at`
- `duration_sec`
- `area_m2`
- `source_device`
- `pet_id` (선택)

서버 동작:
- `walk_sessions`를 `id` 기준 upsert
- 동일 세션 재전송은 update로 수렴

### 3.2 points stage
필수 payload 키:
- `walk_session_id`
- `point_count`
- `points_json` (JSON 배열 문자열)

서버 동작:
- `walk_points`를 `(walk_session_id, seq_no)` 기준 upsert
- 배치 insert + on conflict update로 멱등 보장

### 3.3 meta stage
payload 키:
- `walk_session_id`
- `has_image`
- `map_image_url`

서버 동작:
- map image URL 등 메타만 patch
- 이미지 부재(`has_image=false`)여도 session/points 이관은 성공으로 처리

## 4. Edge Function 계약 (`sync-walk`)
액션:
- `sync_walk_stage`
  - 단일 stage 저장 처리
- `get_backfill_summary`
  - 사용자 기준 이관 합계 조회
  - 반환: `session_count`, `point_count`, `total_area_m2`, `total_duration_sec`

인증:
- 앱 토큰(`Authorization: Bearer`) 기반 사용자 식별
- 서비스 키를 앱에 저장하지 않는다

## 5. 검증 리포트
`GuestDataUpgradeReport`는 로컬/원격 합계를 함께 저장한다.

- 로컬: `sessionCount`, `pointCount`, `totalAreaM2`, `totalDurationSec`
- 원격: `remoteSessionCount`, `remotePointCount`, `remoteTotalAreaM2`, `remoteTotalDurationSec`
- 판정: `validationPassed`, `validationMessage`

허용 오차:
- 세션 수: 완전 일치
- 포인트 수: 완전 일치
- 면적: `abs(local-remote) <= max(1.0, local*0.01)`
- 시간: `abs(local-remote) <= max(3.0, local*0.01)`

## 6. 운영/재시도 기준
- 네트워크/서버 일시 오류: retryable (`offline`, `server_error`)
- 스키마 불일치: permanent (`schema_mismatch`)
- 영구실패 항목은 `requeuePermanentFailures`로 재큐잉
- `sync-walk` session stage는 아래 성격을 구분한다.
  - `422`: 같은 payload로는 성공할 수 없는 데이터 오류 (`pet_id` 누락/무효, 시간 역전, schema constraint)
  - `409`: ownership/context conflict
  - `503/500`: 일시적 또는 미분류 서버 오류
- 영구실패가 난 세션은 같은 세션의 후속 stage도 함께 격리해, 다른 정상 세션 동기화는 계속 진행한다.

## 7. 완료 기준
- 동일 스냅샷 재실행 시 세션/포인트 합계가 증가하지 않는다.
- 재시도 후 `pending=0`, `permanentFailure=0`에 수렴한다.
- 검증 리포트가 로컬/원격 합계와 판정 결과를 저장한다.
