# Multi-Pet Walk Session N:M Design v2

## 1. 목적
`walk_session_pets` 기반 N:M 모델을 2차 구현 기준으로 확정한다.
본 문서는 다중 반려견 동시 산책 구현 전의 단일 기준 문서다.

연결 이슈:
- 선행: #69 (전역 반려견 컨텍스트 동기화)
- 본 설계: #64 (N:M 2차 설계)

## 2. 현재 상태
- `walk_sessions.pet_id` 단일 귀속이 운영 기준 경로다.
- `walk_session_pets` 브릿지 테이블은 계약만 있고 운영 경로 미적용 상태다.
- 홈/목록/통계/상세는 단일 귀속 전제를 기본으로 렌더링한다.

## 3. N:M 도메인 규칙

### 3.1 핵심 엔티티
- `walk_sessions`
  - 산책 세션 원장
  - `pet_id`는 호환성 유지용 `primary_pet_id` 역할
- `walk_session_pets`
  - 다중 반려견 귀속 브릿지
  - 1세션-복수반려견 연결의 정본

### 3.2 규칙
1. 주 반려견(primary pet)
- 세션 생성 시 반드시 1마리 지정
- `primary_pet_id ∈ assigned_pet_ids`

2. 복수 귀속
- 최소 1마리, 최대 5마리(v2 정책)
- 중복 pet id 금지

3. 통계 중복 방지
- `ALL pets` 모드에서는 세션을 `walk_session_id`로 dedupe해 1회만 집계
- `Selected pet` 모드에서는 해당 pet에 연결된 세션만 포함

4. 삭제/비활성
- 세션 삭제 시 브릿지 row cascade 삭제
- pet 비활성화는 세션 보존, 신규 선택만 차단

### 3.3 결정 테이블
| 케이스 | primary pet | assigned pets | 저장 허용 | 집계 규칙 |
|---|---|---|---|---|
| 단일 산책 | A | [A] | 허용 | 기존과 동일 |
| 다중 산책 | A | [A,B] | 허용 | all 모드 dedupe |
| primary 불포함 | A | [B,C] | 거부 | N/A |
| 중복 pet | A | [A,A,B] | 거부 | N/A |

## 4. 저장/조회 API 스펙

### 4.1 저장 계약 (App Repository)
- v1:
  - `saveWalk(session, points, petId)`
- v2:
  - `saveWalk(session, points, primaryPetId, assignedPetIds)`
- 검증:
  - `assignedPetIds.count >= 1`
  - `assignedPetIds` dedupe 후 `primaryPetId` 포함

### 4.2 서버 계약 (Supabase Function/RPC 초안)
1. `rpc_upsert_walk_session_with_pets`
- 입력:
```json
{
  "walk_session_id": "uuid",
  "owner_user_id": "uuid",
  "primary_pet_id": "uuid",
  "assigned_pet_ids": ["uuid","uuid"],
  "duration_sec": 1800,
  "area_m2": 3200.5
}
```
- 출력:
```json
{
  "walk_session_id": "uuid",
  "assigned_count": 2,
  "status": "ok"
}
```

2. `rpc_get_walk_sessions_by_pet`
- 입력:
```json
{
  "owner_user_id": "uuid",
  "pet_id": "uuid",
  "date_from": "2026-01-01",
  "date_to": "2026-02-01"
}
```
- 출력: 세션 목록 + `assigned_pet_ids`

3. `rpc_get_walk_stats`
- 입력:
```json
{
  "owner_user_id": "uuid",
  "mode": "selected|all",
  "pet_id": "uuid|null",
  "period": "week|month|all"
}
```
- 출력: `total_area_m2`, `total_duration_sec`, `session_count`

## 5. 홈/목록/상세 다견 표시 규칙

### 5.1 홈
- `Selected pet` 기본 모드 유지
- `ALL` 토글 시 집계는 dedupe 규칙 적용
- 카드/통계 하단에 기준 배지:
  - `기준: 코코(선택)`
  - `기준: 전체 반려견(중복제외)`

### 5.2 목록
- 세션 카드에 태그형 뱃지:
  - `대표: 코코`
  - `함께: 모카, 루루`
- pet 필터 적용 시 브릿지 join 결과 기준으로 노출

### 5.3 상세
- 상단 메타에 `함께 산책한 반려견` 섹션 고정
- 대표 pet는 별도 badge(`대표`)

## 6. 활성화/마이그레이션 전략

### 6.1 단계별 전환
1. 단계 A: 스키마 보강
- `walk_session_pets` unique/index/FK 확정

2. 단계 B: 백필(idempotent)
- source: `walk_sessions(id, pet_id)`
- target: `walk_session_pets(walk_session_id, pet_id)`
- `ON CONFLICT DO NOTHING`

3. 단계 C: Dual write
- 신규 저장 시 `walk_sessions` + `walk_session_pets` 동시 저장
- 트랜잭션 실패 시 전체 rollback

4. 단계 D: Read path 전환
- 조회 우선순위:
  - flag on: `walk_session_pets` join
  - flag off: 기존 `walk_sessions.pet_id`
- flags:
  - `ff_walk_session_pets_write_v2`
  - `ff_walk_session_pets_read_v2`

5. 단계 E: 안정화
- 정합성/쿼리 지연/오류율 모니터링 후 fallback 축소

### 6.2 영향도 분석
1. 데이터 모델
- 세션당 pet 귀속 cardinality 1 -> N
- 정합성 키 `(walk_session_id, pet_id)` 필요

2. 통계 로직
- all 모드 dedupe 미적용 시 과대집계 리스크
- selected/all 두 모드의 쿼리 경로 분리 필요

3. UI
- 세션 카드 높이 증가(뱃지 영역)
- 작은 화면에서 태그 줄바꿈 정책 필요

4. 마이그레이션/백필
- 대량 백필 시 잠금/성능 이슈 가능
- 배치형 백필 + 검증 쿼리 반복 필요

## 7. 검증 쿼리

### 7.1 백필 누락/중복
```sql
select count(*) as missing
from walk_sessions ws
left join walk_session_pets wsp on ws.id = wsp.walk_session_id
where ws.pet_id is not null
  and wsp.walk_session_id is null;
```

```sql
select walk_session_id, pet_id, count(*)
from walk_session_pets
group by walk_session_id, pet_id
having count(*) > 1;
```

### 7.2 all 모드 dedupe 검증
```sql
select
  sum(ws.area_m2) as naive_sum,
  sum(distinct_ws.area_m2) as deduped_sum
from walk_sessions ws
join walk_session_pets wsp on ws.id = wsp.walk_session_id
join (
  select distinct ws2.id, ws2.area_m2
  from walk_sessions ws2
  join walk_session_pets wsp2 on ws2.id = wsp2.walk_session_id
  where ws2.owner_user_id = :owner_user_id
) as distinct_ws on distinct_ws.id = ws.id
where ws.owner_user_id = :owner_user_id;
```

## 8. 2차 구현 이슈 분해 (초안)
1. `write path`:
- 저장 계약 v2/dual write 트랜잭션

2. `read path`:
- pet별/ALL 통계 조회 분기 및 dedupe 쿼리

3. `ui`:
- 목록/상세 태그형 반려견 뱃지

4. `migration`:
- 백필 배치 + 검증 쿼리 자동화

5. `qa`:
- 단일/복수/ALL 모드 정합성 회귀 테스트 세트

## 9. 구현 착수 조건
- [ ] `supabase/migrations` N:M draft SQL 준비
- [ ] 저장/조회 RPC 시그니처 확정
- [ ] UI 표시 규칙(홈/목록/상세) 리뷰 승인
- [ ] 이슈 분해(쓰기/읽기/UI/마이그레이션/QA) 등록
