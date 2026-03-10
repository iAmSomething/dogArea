# Sync Walk Session Stage Error Policy v1

Issue: `#686`, `#687`

## 1. 목적
- `sync-walk`의 `session` stage가 영구적인 데이터 오류를 generic `500`으로 뭉개지 않도록 분류 계약을 고정한다.
- root cause를 `request_id`, `walk_session_id`, `scope=upsert_session`, DB error detail 기준으로 설명 가능한 상태로 만든다.
- 영구 오류 session 하나가 outbox 전체를 장시간 막지 않도록 앱 정책을 같이 정리한다.

## 2. 2026-03-11 실재현 근거
실배포 함수에 member token으로 아래 payload를 전송해 재현했다.

### 2.1 `pet_id` 누락
- `request_id`: `investigate-missing-pet`
- `walk_session_id`: `00000000-0000-4000-8000-000000006861`
- 응답: `500`
- detail: `null value in column "pet_id" of relation "walk_sessions" violates not-null constraint`

### 2.2 존재하지 않는 `pet_id`
- `request_id`: `investigate-invalid-pet`
- `walk_session_id`: `00000000-0000-4000-8000-000000006862`
- 응답: `500`
- detail: `insert or update on table "walk_sessions" violates foreign key constraint "walk_sessions_pet_id_fkey"`

### 2.3 종료 시간이 시작 시간보다 빠름
- `request_id`: `investigate-reverse-time-valid-pet`
- `walk_session_id`: `00000000-0000-4000-8000-000000006864`
- 응답: `500`
- detail: `new row for relation "walk_sessions" violates check constraint "walk_sessions_ended_after_started_check"`

## 3. root cause 정리
- 실제 반복 `500`의 1차 축은 `session payload`가 `walk_sessions` 제약을 만족하지 못하는 경우다.
- 특히 아래 3개는 같은 payload로 재전송해도 성공하지 않는 영구 오류다.
  - `pet_id` 누락
  - 서버 `pets`에 없는 `pet_id`
  - `ended_at < started_at`
- `owner_user_id` mismatch는 session stage의 최우선 root cause가 아니다.
  - `sync-walk`는 `owner_user_id`를 payload에서 받지 않고, member auth context의 `userId`를 서버에서 강제로 주입한다.
  - 따라서 owner mismatch는 주로 `pet ownership/RLS conflict` 또는 기존 session ownership conflict 형태로 나타난다.

## 4. 서버 분류 계약
`session` stage는 아래 상태 코드를 canonical로 사용한다.

### 4.1 permanent
- `422`
  - `PET_ID_REQUIRED`
  - `SESSION_INVALID_PET_REFERENCE`
  - `SESSION_TIME_RANGE_INVALID`
  - 기타 schema/constraint 위반
- `409`
  - `SESSION_OWNERSHIP_CONFLICT`
  - `SESSION_CONFLICT`

### 4.2 retryable
- `503`
  - `SESSION_TRANSIENT_DB_FAILURE`
- `500`
  - `SESSION_UNKNOWN_DB_FAILURE`

응답 body는 최소 아래 필드를 포함한다.
- `ok`
- `version`
- `request_id`
- `walk_session_id`
- `stage`
- `scope`
- `retryable`
- `code`
- `message`
- `detail`

## 5. 앱 transport / outbox 정책
- `409`, `422`는 `permanent`로 내려 retry queue에 남기지 않는다.
- `500`, `503`, `429`는 `retryable(.serverError)`로 유지한다.
- `session` stage가 permanent 실패하면:
  - 현재 stage를 `permanentFailed`
  - 같은 `walkSessionId`의 후속 `points/meta` stage도 함께 `permanentFailed`
  - 다른 정상 session flush는 계속 진행

## 6. 검증 기준
- 정상 member smoke:
  - `sync-walk.session.member` => `200`
- invalid payload 분류:
  - `pet_id` 누락 => `422`
  - invalid `pet_id` => `422`
  - `ended_at < started_at` => `422`
- static checks:
  - session stage source에 canonical code/status가 존재
  - transport가 `409/422`를 permanent로 분류
  - outbox가 permanent session을 격리하고 다음 session flush를 계속 수행
