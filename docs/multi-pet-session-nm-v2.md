# Multi-Pet Walk Session N:M Design v2

## 1. 목적
`walk_session_pets`를 실제 운영 경로에 활성화하기 위한 2차 설계를 확정한다.
본 문서는 #27 구현 착수 전 단일 기준 문서다.

연결 이슈:
- 선행: #26 (다견 1차 UX)
- 본 설계: #27 (N:M 2차)

## 2. 현재 상태
- `walk_sessions.pet_id` 단일 귀속이 기준 경로다.
- `walk_session_pets`는 스키마상 존재하지만, 읽기/쓰기 주 경로에 아직 미적용이다.
- 집계(홈/목록/주간 통계)는 사실상 `walk_sessions.pet_id` 전제다.

## 3. walk_session_pets 활성화 전략

## 3.1 활성화 목표
- 산책 1건에 복수 반려견 연결 가능
- 1차 호환성 유지를 위해 `walk_sessions.pet_id`(primary pet)는 유지
- 읽기/쓰기 전환을 단계적으로 수행

## 3.2 단계별 전환
1. 단계 A: 스키마 보강
- `walk_session_pets` 제약/인덱스 확정
  - PK/UNIQUE: `(walk_session_id, pet_id)`
  - index: `(pet_id, walk_session_id)`
- FK cascade 정책 명시

2. 단계 B: 백필 (idempotent)
- 기존 `walk_sessions` 행을 `walk_session_pets`로 백필
- 규칙:
  - insert source: `(walk_sessions.id, walk_sessions.pet_id)`
  - `ON CONFLICT DO NOTHING`
- 검증:
  - `walk_sessions` 행 수 <= `walk_session_pets` distinct session 수
  - 누락 session 0건

3. 단계 C: Dual write
- 신규 산책 저장 시
  - `walk_sessions.pet_id = primaryPetId`
  - `walk_session_pets`에 `petIds[]` 전량 insert
- 트랜잭션 단위로 처리(둘 중 하나만 성공 금지)

4. 단계 D: Read path 전환
- pet 기준 조회는 `walk_session_pets` 우선
- fallback은 `walk_sessions.pet_id` (플래그 off 시)
- feature flag:
  - `ff_walk_session_pets_read_v2`
  - `ff_walk_session_pets_write_v2`

5. 단계 E: 안정화
- 오류율/지연/정합성 모니터링
- fallback 제거 시점 결정

## 3.3 쓰기 계약 (Repository)
- v1:
  - `saveWalk(session, points, petId)`
- v2:
  - `saveWalk(session, points, primaryPetId, petIds)`
- 제약:
  - `petIds`는 1개 이상
  - `primaryPetId ∈ petIds`
  - 중복 pet id 제거 후 저장

## 4. 집계 변경 영향 분석

## 4.1 영향 대상
- 홈: 총 면적/총 시간, 주간 통계
- 목록: 반려견 필터 결과
- 히트맵/좌표 기반 집계
- 명소 달성/마일스톤

## 4.2 집계 규칙
1. Selected pet 모드
- `walk_session_pets.pet_id = selectedPetId`인 session만 포함
- 면적/시간은 session 원값 그대로 사용

2. All pets 모드
- session 중복 합산 금지
- key: `walk_session_id`로 dedupe 후 1회만 합산
- 이유: 다중 반려견 산책 1건이 총량에서 2배 집계되는 오류 방지

3. 포인트/히트맵
- pet 필터 시 `walk_session_pets` join
- all 모드에서 point 중복 제거(`walk_points.id` 기준)

4. 마일스톤
- pet별 마일스톤은 selected pet 기준 유지
- all 모드 마일스톤은 별도 aggregate milestone로 분리(혼합 금지)

## 4.3 쿼리 변경 포인트
- 기존:
  - `from walk_sessions where pet_id = :petId`
- 변경:
  - `from walk_sessions ws join walk_session_pets wsp on ws.id = wsp.walk_session_id where wsp.pet_id = :petId`
- all 모드:
  - `select distinct ws.id ...`

## 5. 마이그레이션 리스크 정리

## 5.1 데이터 리스크
1. 백필 누락
- 원인: 중단/부분 실행
- 대응: idempotent 백필 + 검증 쿼리 반복

2. 중복 row
- 원인: 재실행/중복 입력
- 대응: `(walk_session_id, pet_id)` unique

3. 고아 row
- 원인: pet/session 삭제 순서 문제
- 대응: FK + on delete cascade 정책 확정

## 5.2 애플리케이션 리스크
1. Dual write 불일치
- 원인: partial failure
- 대응: DB 트랜잭션 + 실패 시 전부 rollback

2. 집계 과대 계산
- 원인: all 모드 dedupe 누락
- 대응: 집계 쿼리 강제 `distinct walk_session_id`

3. 성능 저하
- 원인: join 증가
- 대응: 인덱스 + 쿼리 계획 점검 + 캐시

## 5.3 운영 리스크
1. 플래그 전환 오류
- 대응: read/write 플래그 분리, 점진 활성화
2. 롤백 시 데이터 분기
- 대응: rollback 시 read 경로만 v1로 즉시 복귀, write는 dual 유지

## 6. 검증 쿼리/체크리스트

## 6.1 백필 검증
- session 누락 검증
```sql
select count(*) as missing
from walk_sessions ws
left join walk_session_pets wsp on ws.id = wsp.walk_session_id
where wsp.walk_session_id is null;
```

- 중복 검증
```sql
select walk_session_id, pet_id, count(*)
from walk_session_pets
group by walk_session_id, pet_id
having count(*) > 1;
```

## 6.2 집계 정합 검증
- selected pet 모드/기존 v1 결과 비교(샘플 사용자)
- all 모드에서 다중 pet session 중복 없는지 검증

## 7. 구현 착수 조건
- [ ] write/read 플래그 정의 완료
- [ ] backfill SQL 초안 작성 완료
- [ ] repository 계약(v2 시그니처) 확정
- [ ] QA 케이스(단일/다중/ALL 모드) 작성 완료
